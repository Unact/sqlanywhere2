# frozen_string_literal: true

require 'rake/extensiontask'

Rake::ExtensionTask.new do |ext|
  ext.name = 'sqlanywhere2'
  ext.lib_dir = 'lib/sqlanywhere2'
  ext.ext_dir = 'ext/sqlanywhere2'
  ext.tmp_dir = 'tmp'
  ext.source_pattern = '*.c'
  ext.gem_spec = Gem::Specification.load('sqlanywhere2.gemspec')
end
