# frozen_string_literal: true

require 'rake/extensiontask'
require 'rspec/core/rake_task'

Rake::ExtensionTask.new do |ext|
  ext.name = 'sqlanywhere2'
  ext.lib_dir = 'lib/sqlanywhere2'
  ext.ext_dir = 'ext/sqlanywhere2'
  ext.tmp_dir = 'tmp'
  ext.source_pattern = '*.c'
  ext.gem_spec = Gem::Specification.load('sqlanywhere2.gemspec')
end

begin
  RSpec::Core::RakeTask.new('spec') do |t|
    t.verbose = true
    t.prerequisites = [:compile]
  end
rescue LoadError
  puts 'You must `gem install rspec` and `bundle install` to run rake tasks'
end
