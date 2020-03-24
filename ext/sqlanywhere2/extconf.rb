# frozen_string_literal: true

require 'mkmf'

extension_name = 'sqlanywhere2'

sqlany_path_key = ENV.keys.find { |key| key.match(/SQLANY.\d/) }

raise 'SQL Anywhere SQLANY environment variable not found' if sqlany_path_key.nil?

sqlany_path = ENV[sqlany_path_key]
sdk_path =
  if RUBY_PLATFORM =~ /darwin/
    sqlany_path + '/../sdk/include/'
  else
    sqlany_path + '/sdk/include/'
  end

platform_version = 1.size > 4 ? '64' : '32'
lib_path =
  if RUBY_PLATFORM =~ /mingw|mswin/
    "#{sqlany_path}/bin#{platform_version}"
  else
    "#{sqlany_path}/lib#{platform_version}"
  end

if RUBY_PLATFORM =~ /mingw|mswin/
  $LOCAL_LIBS << ' dbcapi.dll'
else
  $LOCAL_LIBS << '-ldbcapi_r'
end

dir_config(extension_name, sdk_path, lib_path)

create_makefile("#{extension_name}/#{extension_name}")
