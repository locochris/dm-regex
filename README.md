dm-regex
===

[![Build Status](https://travis-ci.org/locochris/dm-regex.png?branch=master)](https://travis-ci.org/locochris/dm-regex)
[![Gem Version](https://badge.fury.io/rb/dm-regex.png)](http://badge.fury.io/rb/dm-regex)
[![Dependency Status](https://gemnasium.com/locochris/dm-regex.png)](https://gemnasium.com/locochris/dm-regex)


dm-regex is a glorifed wrapper to `Regexp.compile` that matches against strings to build a family of DataMapper models.

It works by mapping [named regexp groups](http://ruby.about.com/od/newinruby191/a/namedreg.htm) to DataMapper [properties](http://datamapper.org/docs/properties.html) and [associations](http://datamapper.org/docs/associations.html).

Those groups are then referenced in the pattern string passed to `compile` using `\g<name>`, where `name` is the name of the property.

Associations can also be referenced in the same way; their pattern values come from embeddable versions of their compiled regexes.

To do all this `DataMapper::Resource` is extended with the following class methods:

### `property(opts)`
 * a wrapper for DM's `property`, that first extracts any `:pat` and `:method` options
   * `:pat` option specifies the pattern used to match the property.
     (NB. the default pattern of `/.+?/` might be good enough in most cases)
   * `:method` option takes a proc that is used to transform the matched value.
     (NB. DataMapper's built-in typescasting might be good enough in most cases)

### `compile(pattern, options=0)`
 * a glorified wrapper for `Regexp.compile` that uses the `MatchData` to build models
 * uses named groups specified using `\g<name>` syntax to map groups to property regexes.
   (NB. make sure to use `\\g` when using double quoted strings)

### `match(str, relationship=self)`
 * builds a model by matching against `str` (returns nil on failure)
 * where defined, uses the `:pat` regex to match property values
 * where defined, uses the transforming `:method` to transform property values
 * if the parent relationship is given it adds the model to that relationship,
 * otherwise it recursivly builds and adds models to all the parent relationships
   (ie. building up a model "tree" from each "leaf")
 * or iteratively adds child models to the parent
   (ie. building up model "leaves" for the "tree")


Installation
---

```
gem install dm-regex
```


Example Usages
---

### Example: Matching ManyToOne
``` ruby
require 'dm-regex'

class Host
  include DataMapper::Resource

  property :id    , Serial
  property :value , String , :pat => /[.0-9]+/

  has n, :requests

  # 87.18.183.252
  compile '^\g<value>$'
end

class UserAgent
  include DataMapper::Resource

  property :id    , Serial
  property :value , String

  has n, :requests

  # Feedreader 3.13 (Powered by Newsbrain)
  compile '^\g<value>$'
end

class Verb
  include DataMapper::Resource

  property :id    , Serial
  property :value , String

  has n, :request_types
  has n, :requests, :through => :request_types

  # GET
  compile '^\g<value>$'
end

class RequestType
  include DataMapper::Resource

  property :id       , Serial
  property :path     , String
  property :protocol , String , :pat => %r{HTTP/\d.\d}

  belongs_to :verb
  has n, :requests

  # GET /blog/index.xml HTTP/1.1
  compile '^\g<verb> \g<path> \g<protocol>$'
end

class Referer
  include DataMapper::Resource

  property :id    , Serial
  property :value , String , :pat => /.+/ , :method => lambda { |value| value unless value == '-' }

  has n, :requests

  # -
  compile '^\g<value>$'
end

class Request
  include DataMapper::Resource

  property :id      , Serial
  property :l       , String   , :method => lambda { |value| value unless value == '-' }
  property :u       , String   , :method => lambda { |value| value unless value == '-' }
  property :t       , DateTime , :method => lambda { |value| DateTime.strptime(value, '%d/%b/%Y:%H:%M:%S %z') }
  property :s       , Integer
  property :b       , Integer

  belongs_to :host
  belongs_to :request_type
  belongs_to :user_agent
  belongs_to :referer

  has 1, :verb, :through => :request_type

  # 87.18.183.252 - - [13/Aug/2008:00:50:49 -0700] "GET /blog/index.xml HTTP/1.1" 302 527 "-" "Feedreader 3.13 (Powered by Newsbrain)"
  #compile '^\g<host> \g<l> \g<u> \[\g<t>\] "\g<request_type>" \g<s> \g<b> "\g<referer>" "\g<user_agent>"$'
  compile %{
    ^
    \\g<host>           # This is an EXTENDED regex
    [ ]
    \\g<l>              # it can have comments
    [ ]
    \\g<u>              # and more comments
    [ ]\\[
    \\g<t>              # but IMHO this is
    \\]
    [ ]"
    \\g<request_type>   # a lot harder to follow
    "[ ]                # than the commented out example above
    \\g<s>              #
    [ ]                 # Actually the groups names
    \\g<b>              # are self-documenting anyway
    [ ]"                # aren't they?
    \\g<referer>        # Plus every \ needs to be escaped
    "[ ]"               # which is a bit of a pain.
    \\g<user_agent>     # Anyway .. your choice
    "$
  }, Regexp::EXTENDED
end

DataMapper.setup :default, "sqlite::memory:"
require 'dm-migrations'
DataMapper.auto_upgrade!

%{\
87.18.183.252 - - [13/Aug/2008:00:50:49 -0700] "GET /blog/index.xml HTTP/1.1" 302 527 "-" "Feedreader 3.13 (Powered by Newsbrain)"
79.28.16.191 - - [13/Aug/2008:00:50:55 -0700] "GET /blog/public/2008/08/gmail-offline-dati-a-rischio/gmaildown.png HTTP/1.1" 304 283 "-" "FeedDemon/2.7 (http://www.newsgator.com/; Microsoft Windows XP)"
79.28.16.191 - - [13/Aug/2008:00:50:55 -0700] "GET /blog/public/2008/08/nuovo-microsoft-webmaster-center/overview.png HTTP/1.1" 304 283 "-" "FeedDemon/2.7 (http://www.newsgator.com/; Microsoft Windows XP)"
69.150.40.169 - - [13/Aug/2008:00:51:06 -0700] "POST http://www.simonecarletti.com/mt4/mt-ttb.cgi/563 HTTP/1.1" 404 610 "-" "-"
217.220.110.75 - - [13/Aug/2008:00:51:02 -0700] "GET /blog/2007/05/microsoft-outlook-pst.php HTTP/1.1" 200 82331 "http://www.google.it/search?hl=it&q=outlook+pst+file+4+GB&meta=" "Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; SV1; Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1; SV1) ; .NET CLR 1.1.4322; .NET CLR 2.0.50727)"\
}.split("\n").each do |line|
  Request.match(line).tap(&:save)
end

p get = Verb.first(:value => 'GET')
# => #<Verb @id=1 @value="GET">
p get.requests
# => [#<Request @id=1 @l=nil @u=nil @t=#<DateTime: 2008-08-13T00:50:49-07:00 ((2454692j,28249s,0n),-25200s,2299161j)> @s=302 @b=527 @host_id=1 @request_type_id=1 @user_agent_id=1 @referer_id=1>, #<Request @id=2 @l=nil @u=nil @t=#<DateTime: 2008-08-13T00:50:55-07:00 ((2454692j,28255s,0n),-25200s,2299161j)> @s=304 @b=283 @host_id=2 @request_type_id=2 @user_agent_id=2 @referer_id=1>, #<Request @id=3 @l=nil @u=nil @t=#<DateTime: 2008-08-13T00:50:55-07:00 ((2454692j,28255s,0n),-25200s,2299161j)> @s=304 @b=283 @host_id=2 @request_type_id=3 @user_agent_id=2 @referer_id=1>, #<Request @id=5 @l=nil @u=nil @t=#<DateTime: 2008-08-13T00:51:02-07:00 ((2454692j,28262s,0n),-25200s,2299161j)> @s=200 @b=82331 @host_id=4 @request_type_id=5 @user_agent_id=4 @referer_id=2>]

p a_host = Host.first(:value => '79.28.16.191')
# => #<Host @id=2 @value="79.28.16.191">
p a_host.requests
# => [#<Request @id=2 @l=nil @u=nil @t=#<DateTime: 2008-08-13T00:50:55-07:00 ((2454692j,28255s,0n),-25200s,2299161j)> @s=304 @b=283 @host_id=2 @request_type_id=2 @user_agent_id=2 @referer_id=1>, #<Request @id=3 @l=nil @u=nil @t=#<DateTime: 2008-08-13T00:50:55-07:00 ((2454692j,28255s,0n),-25200s,2299161j)> @s=304 @b=283 @host_id=2 @request_type_id=3 @user_agent_id=2 @referer_id=1>]

p a_referer = Referer.last
# => #<Referer @id=2 @value="http://www.google.it/search?hl=it&q=outlook+pst+file+4+GB&meta=">
p a_referer.requests.hosts
# => [#<Host @id=4 @value="217.220.110.75">]
```

### Example: Matching with a relationship
``` ruby
require 'dm-regex'

class Blog
  include DataMapper::Resource

  property :id   , Serial
  property :name , String

  has n, :posts
end

class Post
  include DataMapper::Resource

  property :id     , Serial
  property :title  , String , :pat => /[^,]+/
  property :author , String

  belongs_to :blog

  # my interesting blog, m@blog.com"
  compile '^\g<title>, \g<author>$'
end

DataMapper.setup :default, "sqlite::memory:"
require 'dm-migrations'
DataMapper.auto_upgrade!

blog = Blog.first_or_create(:name => 'foo')
Post.match("my interesting blog, me@blog.com", blog.posts).tap(&:save)
p blog.posts
# => [#<Post @id=1 @title="my interesting blog" @author="me@blog.com" @blog_id=1>]
```

### Example: Matching OneToMany
``` ruby
require 'dm-regex'

class Sentence
  include DataMapper::Resource

  property :id    , Serial
  property :value , String

  has n, :words

  compile '^(?<value>(.*?\g<word>.*?)+(\.|\?|\!))$', Regexp::MULTILINE
end

class Word
  include DataMapper::Resource

  property :id    , Serial
  property :value , String , :pat => /\b\w+\b/

  belongs_to :sentence

  compile '\g<value>'
end

DataMapper.setup :default, "sqlite::memory:"
require 'dm-migrations'
DataMapper.auto_upgrade!

str = "One two\nthree four."

Sentence.match(str).tap(&:save)

p Sentence.all
# => [#<Sentence @id=1 @value="One two\nthree four.">]
p Sentence.first.words
# => [#<Word @id=1 @value="One" @sentence_id=1>, #<Word @id=2 @value="two" @sentence_id=1>, #<Word @id=3 @value="three" @sentence_id=1>, #<Word @id=4 @value="four" @sentence_id=1>]
```

# Gotchas
  * When passing a double quoted string argument to `compile` make sure to use `\\g` for groups and not `\g`
