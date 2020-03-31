# frozen_string_literal: true

require 'rake'

load 'tasks/sqlanywhere.rake'
load 'tasks/compile.rake'
load 'tasks/rspec.rake'

begin
  require 'rubocop/rake_task'

  RuboCop::RakeTask.new
  task default: %i[spec rubocop]
rescue LoadError
  warn 'RuboCop is not available'
  task default: :spec
end
