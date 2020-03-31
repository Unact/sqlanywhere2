# frozen_string_literal: true

require 'rspec/core/rake_task'

begin
  RSpec::Core::RakeTask.new('spec') do |t|
    t.verbose = true
  end

  Rake::Task[:spec].prerequisites << :compile
  Rake::Task[:spec].prerequisites << 'sqlanywhere:init'
rescue LoadError
  puts 'You must `gem install rspec` and `bundle install` to run rake tasks'
end
