# frozen_string_literal: true

require File.expand_path('lib/sqlanywhere2/version', __dir__)

Gem::Specification.new do |gem|
  gem.name = 'sqlanywhere2'
  gem.version = SQLAnywhere2::VERSION
  gem.authors = ['Unact']
  gem.license = 'MIT'
  gem.email = 'it@unact.ru'
  gem.summary = 'A simple SQL Anywhere library for Ruby'
  gem.extensions = ['ext/sqlanywhere2/extconf.rb']
  gem.homepage = 'https://github.com/Unact/sqlanywhere2'
  gem.files = `git ls-files README.md CHANGELOG.md LICENSE ext lib`.split
  gem.test_files = `git ls-files spec`.split

  gem.required_ruby_version = '>= 2.3.0'
end
