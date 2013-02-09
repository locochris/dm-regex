# -*- encoding: utf-8 -*-
require File.expand_path('../lib/dm-regex/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors     = [ 'locochris' ]
  gem.email       = [ 'chris@locomote.com.au' ]
  gem.summary     = 'DataMapper plugin enabling models to be created from matching a regex'
  gem.description = gem.summary
  gem.homepage    = "http://github.com/locomote/dm-regex"

  gem.files            = `git ls-files`.split("\n")
  gem.test_files       = `git ls-files -- {spec}/*`.split("\n")

  gem.name          = 'dm-regex'
  gem.require_paths = [ "lib" ]
  gem.version       = DataMapper::Regex::VERSION

  gem.required_ruby_version = '>= 1.9.2'

  gem.add_runtime_dependency('dm-core', '~> 1.0')
  gem.add_runtime_dependency('dm-migrations', '~> 1.0')
  gem.add_runtime_dependency('dm-sqlite-adapter', '~> 1.0')

  gem.add_development_dependency('rake', '~> 10.0')
  gem.add_development_dependency('rspec', '~> 2.0')
  gem.add_development_dependency('rdd', '~> 0.0')
  gem.add_development_dependency('pry')
end
