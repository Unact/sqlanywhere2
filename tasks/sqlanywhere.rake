# frozen_string_literal: true

require 'rake/clean'

namespace :sqlanywhere do
  test_db_file = 'tmp/test.db'

  desc 'Initialize the sqlanywhere database'
  task :init do
    sh("dbinit #{test_db_file}") unless File.exist?(test_db_file)
  end
end
