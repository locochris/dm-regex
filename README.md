dm-regex
===

[![Build Status](https://travis-ci.org/locomote/dm-regex.png)](https://travis-ci.org/locomote/dm-regex)

Installation
---

```
gem install dm-regex
```

Usage
---
``` ruby
require 'dm-regex'

class ApacheLogEntry
  include DataMapper::Resource

  property :id         , Serial
  property :h          , String    , :pat => /[.0-9]+?/
  property :l          , String
  property :u          , String
  property :t          , DateTime  , :method => lambda { |value| DateTime.strptime(value, '%d/%b/%Y:%H:%M:%S %z') }
  property :r          , String
  property :s          , Integer
  property :b          , Integer
  property :referer    , String
  property :user_agent , String

  compile '^\g<h> \g<l> \g<u> \[\g<t>\] "\g<r>" \g<s> \g<b> "\g<referer>" "\g<user_agent>"$'
end


DataMapper.setup :default, "sqlite::memory:"
require 'dm-migrations'
DataMapper.auto_upgrade!

p ApacheLogEntry.match(
  '87.18.183.252 - - [13/Aug/2008:00:50:49 -0700] "GET /blog/index.xml HTTP/1.1" 302 527 "-" "Feedreader 3.13 (Powered by Newsbrain)"'
)
# => #<ApacheLogEntry @id=nil @h="87.18.183.252" @l="-" @u="-" @t=#<DateTime: 2008-08-13T00:50:49-07:00 ((2454692j,28249s,0n),-25200s,2299161j)> @r="GET /blog/index.xml HTTP/1.1" @s=302 @b=527 @referer="-" @user_agent="Feedreader 3.13 (Powered by Newsbrain)">
```
