# SQLAnywhere2 - A modern, simple SQLAnywhere library for Ruby

SQLAnywhere2 is meant to simplify the process of connecting and executing queries.
SQLAnywhere2 methods are designed to not be blocking.

It does not map 1 to 1 with SQLAnywhere libdbcapi, instead it provides a simple api for connection and query execution.
It also does not support multirow fetching since libdbcapi multi fetching is buggy and sometimes does not return correct results.

__Warning__ libdbcapi does not support execution of queries with procedures which contain INOUT parameters.
If such procedure is used it seldom leads to a ruby VM crash. More info on this below.

__Warning__ libdbcapi does not support preparing statements with more than 32767 params(16-bit integer limit).
If an SQL with this many parameters is prepared, it will lead to a ruby VM crash.

It requires specifing connection encoding for correct translation from returned sql data to ruby.

The API consists of three classes:

`SQLAnywhere2::Connection` - for making a connection with your database.
`SQLAnywhere2::Statement` - returned after executing `execute_direct` or `prepare` on the connection.
`SQLAnywhere2::Result` - returned after executing a query which returns a result set.

## Installing

In your Gemfile

`gem 'sqlanywhere2', github: 'Unact/sqlanywhere2'`

## Usage

Connect to a database:

```ruby
connection = SQLAnywhere2::Connection.new(
  conn_string: "ServerName=MyServer;DatabaseName=MyDatabase;UserID=root;Password=pwd;CharSet=UTF-8;"
)
```

Querying:

```ruby
statement, results = connection.execute_direct("SELECT * FROM products")
```

Since `SQLAnywhere2::Result` includes `Enumerable` you can easily go through all the results like so:

```ruby
# Each row is an array of column results
results.each { |row| puts row }
```

You can get all column info returned by query.
Result row element indexes all correspond to the column with the same index.

```ruby
results.columns
```

## Result types

By default most sql types are casted to their respective ruby type.
Some of those casts might be uneeded.
This can be disabled by passing `:cast` option when making a connection

```ruby
SQLAnywhere2::Connection.new conn_string: "", cast: false
```

### Time/Timestamp timezones

When creating `Time` objects from sql data values you can set which timezone to use using `:database_timezone` option.
Currently only `:local` and `:utc` are supported.
By default SQLAnywhere2 uses `:local` option.

### Bit

All bit values are casted to ruby `TrueClass`/`FalseClass`.

## libdbcapi VM crash

The following example illustrates the problem with libdbcapi

```SQL
create or replace procedure test(@param int)
begin
    select newid() as a
end
```

```ruby
connection = SQLAnywhere2::Connection.new conn_string: "ServerName=MyServer;DatabaseName=MyDatabase;U
serID=root;Password=pwd;CommLinks=tcpip(host=MyHost);CharSet=UTF-8;"

connection.execute_direct("call test()")
```

After executing this code most times ruby VM crashes.
This can be fixed by sending a SET query with procedure call like so

```ruby
connection = SQLAnywhere2::Connection.new conn_string: "ServerName=MyServer;DatabaseName=MyDatabase;U
serID=root;Password=pwd;CommLinks=tcpip(host=MyHost);CharSet=UTF-8;"

connection.execute_immediate('CREATE VARIABLE @@sqlawnywhere2_fix char(1)') if @enable_crash_fix
connection.execute_direct("set @@sqlanywhere2_fix = ''; call test()")
```

Such functionality can be enabled by passing `:enable_crash_fix` option.

## Version support

This gem is tested using SQLAnywhere 16.
Unfotunately it is impossible to test versions below.
In theory it should support all SQLAnywhere versions as long as they support SQLANY_API_VERSION_2.
That means all SQLAnywhere versions up from 12 should work.

All Linux and MacOS Ruby MRI versions from 2.3 are supported.
This is not tested on Windows.

## Development

Use 'bundle install' to install the necessary development and testing gems:

```bash
bundle install
```

After which you can use `rake` command to run rspec tests and rubocop linting
