require 'spec_helper'

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
  property :value , String , :pat => /.+/

  has n, :requests

  # -
  compile '^\g<value>$'
end

class Request
  include DataMapper::Resource

  property :id      , Serial
  property :l       , String
  property :u       , String
  property :t       , DateTime , :method => lambda { |value| DateTime.strptime(value, '%d/%b/%Y:%H:%M:%S %z') }
  property :s       , Integer
  property :b       , Integer

  belongs_to :host
  belongs_to :request_type
  belongs_to :user_agent
  belongs_to :referer

  has 1, :verb, :through => :request_type

  # 87.18.183.252 - - [13/Aug/2008:00:50:49 -0700] "GET /blog/index.xml HTTP/1.1" 302 527 "-" "Feedreader 3.13 (Powered by Newsbrain)"
  compile '^\g<host> \g<l> \g<u> \[\g<t>\] "\g<request_type>" \g<s> \g<b> "\g<referer>" "\g<user_agent>"$'
end

# ----

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
DataMapper.auto_upgrade!


describe DataMapper::Regex do
  describe '.match(str)' do
    subject { Request.match(str).tap(&:save) }

    let(:str) {
      '87.18.183.252 - - [13/Aug/2008:00:50:49 -0700] "GET /blog/index.xml HTTP/1.1" 302 527 "-" "Feedreader 3.13 (Powered by Newsbrain)"'
    }

    its(:l) { should == '-' }
    its(:u) { should == '-' }
    its(:t) { should == DateTime.parse('13/08/2008T00:50:49 -0700') }
    its(:s) { should == 302 }
    its(:b) { should == 527 }

    its(:host) {
      should == Host.first_or_create(:value => '87.18.183.252')
    }
    its(:verb) {
      should == Verb.first_or_create(:value => 'GET')
    }
    its(:referer) {
      should == Referer.first_or_create(:value => '-')
    }
    its(:user_agent) {
      should == UserAgent.first_or_create(:value => 'Feedreader 3.13 (Powered by Newsbrain)')
    }

    context "when no match is found" do
      subject { Request.match(str) }

      let(:str) { 'xxxxx' }

      it { should be_nil }
    end
  end

  describe '.match(str, relationship)' do
    subject { Post.match(str, relationship).tap(&:save) }

    let(:relationship) { Blog.first_or_create(:name => 'foo').posts }

    let(:title ) { 'my interesting blog'                      }
    let(:author) { 'me@blog.com'                              }
    let(:str   ) { "#{title}, #{author}"                      }

    its(:title ) { should == title  }
    its(:author) { should == author }

    its(:blog) {
      should == Blog.first_or_create(:name => 'foo')
    }
  end
end
