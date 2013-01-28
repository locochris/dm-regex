require 'spec_helper'

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

  # 87.18.183.252 - - [13/Aug/2008:00:50:49 -0700] "GET /blog/index.xml HTTP/1.1" 302 527 "-" "Feedreader 3.13 (Powered by Newsbrain)"
  compile '^\g<h> \g<l> \g<u> \[\g<t>\] "\g<r>" \g<s> \g<b> "\g<referer>" "\g<user_agent>"$'
end


DataMapper.setup :default, "sqlite::memory:"
DataMapper.auto_upgrade!

describe DataMapper::Regex do
  describe '.match' do
    subject { ApacheLogEntry.match(line) }

    before :all do

    end

    let(:line) {
      '87.18.183.252 - - [13/Aug/2008:00:50:49 -0700] "GET /blog/index.xml HTTP/1.1" 302 527 "-" "Feedreader 3.13 (Powered by Newsbrain)"'
    }

    its(:h) { should == '87.18.183.252' }
    its(:l) { should == '-' }
    its(:u) { should == '-' }
    its(:t) { should == DateTime.parse('13/08/2008T00:50:49 -0700') }
    its(:r) { should == 'GET /blog/index.xml HTTP/1.1' }
    its(:s) { should == 302 }
    its(:b) { should == 527 }
    its(:referer) { should == '-' }
    its(:user_agent) { should == 'Feedreader 3.13 (Powered by Newsbrain)' }
  end
end
