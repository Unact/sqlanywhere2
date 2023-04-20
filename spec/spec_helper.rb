# frozen_string_literal: true

require 'rspec'
require 'sqlanywhere2'
require 'yaml'

DatabaseCredentials = YAML.load_file('spec/configuration.yml')

RSpec.configure do |config|
  config.disable_monkey_patching!

  # Hold an open connection, so that sqlanywhere database is not shutdown on each example
  global_connection = nil

  config.before(:suite) do
    global_connection = SQLAnywhere2::Connection.new(DatabaseCredentials['root'])
    global_connection.execute_immediate 'DROP TABLE IF EXISTS sqlanywhere2_test'
    global_connection.execute_immediate <<-SQL
      CREATE TABLE sqlanywhere2_test (
        "id" INTEGER PRIMARY KEY,
        "_binary_" BINARY(8) DEFAULT NULL,
        "_unbounded_binary_" LONG BINARY DEFAULT NULL,
        "_numeric_" NUMERIC(2,1),
        "_decimal_" DECIMAL(2,1),
        "_bounded_string_" VARCHAR(255) DEFAULT NULL,
        "_unbounded_string_" LONG VARCHAR DEFAULT NULL,
        "_signed_bigint_" BIGINT DEFAULT NULL,
        "_unsigned_bigint_" UNSIGNED BIGINT DEFAULT NULL,
        "_signed_int_" INTEGER DEFAULT NULL,
        "_unsigned_int_" UNSIGNED INTEGER DEFAULT NULL,
        "_signed_smallint_" SMALLINT DEFAULT NULL,
        "_unsigned_smallint_" UNSIGNED SMALLINT DEFAULT NULL,
        "_signed_tinyint_" TINYINT DEFAULT NULL,
        "_unsigned_tinyint_" UNSIGNED TINYINT DEFAULT NULL,
        "_bit_" BIT NULL,
        "_date_" DATE DEFAULT NULL,
        "_datetime_" DATETIME DEFAULT NULL,
        "_smalldatetime_" SMALLDATETIME DEFAULT NULL,
        "_timestamp_" TIMESTAMP DEFAULT NULL,
        "_double_" DOUBLE DEFAULT NULL,
        "_float_" FLOAT DEFAULT NULL,
        "_real_" REAL DEFAULT NULL
      )
    SQL
    global_connection.execute_immediate <<-SQL
      CREATE OR REPLACE PROCEDURE TEST(@PARAM INT)
      BEGIN
        SELECT NEWID() AS A
      END
    SQL
  end

  config.after(:suite) do
    global_connection.close
  end

  def new_connection(additional_opts = {})
    connection = SQLAnywhere2::Connection.new(DatabaseCredentials['root'].merge(additional_opts))
    @connections ||= []
    @connections.push(connection)
    connection
  end

  config.before :each do
    connection = new_connection
    connection.execute_immediate 'DELETE FROM sqlanywhere2_test'
    connection.execute_immediate <<-SQL
      INSERT INTO sqlanywhere2_test VALUES(
        0,
        CAST(0x78 AS BINARY),
        CAST(0x78 AS BINARY),
        1.1,
        1.1,
        'String Test',
        'String Test',
        9223372036854775807,
        18446744073709551615,
        2147483647,
        4294967295,
        32767,
        65535,
        255,
        255,
        1,
        DATE('1999-01-02 21:20:53'),
        DATETIME('1999-01-02 21:20:53'),
        DATETIME('1999-01-02 21:20:53'),
        DATETIME('1999-01-02 21:20:53'),
        1.79769313486231e+308,
        3.402823e+38,
        3.402823e+38
      );
    SQL
    connection.execute_immediate 'COMMIT'
  end

  config.after :each do
    @connections.each(&:close)
  end
end
