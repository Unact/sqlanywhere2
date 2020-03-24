# frozen_string_literal: true

module SQLAnywhere2
  class Connection
    # rubocop:disable Style/ClassVars
    @@initialized_pids = []
    # rubocop:enable Style/ClassVars

    attr_reader :conn_string, :cast, :database_timezone, :encoding, :enable_crash_fix

    def initialize(opts = {})
      opts = symbolize_opts_keys(opts)
      raise SQLAnywhere2::Error, 'Connection string parameter must be a String' unless opts[:conn_string].is_a?(String)

      process_pid = Process.pid
      conn_opts = parse_conn_string(opts[:conn_string])

      @enable_crash_fix = opts[:enable_crash_fix] || false
      @database_timezone = opts[:database_timezone] || :local
      @cast = opts[:cast].nil? ? true : opts[:cast]
      @encoding = conn_opts['CharSet'] || opts[:encoding] || Encoding.default_external.name

      # Check for correct encoding. This will raise ArgumentError if encoding not found
      Encoding.find(@encoding)
      conn_opts['CharSet'] = @encoding

      if @database_timezone != :utc && @database_timezone != :local
        raise SQLAnywhere2::Error, ':database_timezone option must be :utc or :local'
      end

      @conn_string = build_conn_string(conn_opts)

      unless @@initialized_pids.include?(process_pid)
        initialize_lib
        @@initialized_pids.push(process_pid)
      end

      initialize_connection
      connect(@conn_string)
      execute_immediate('CREATE VARIABLE @@sqlawnywhere2_fix char(1)') if @enable_crash_fix
    end

    def execute_immediate(sql)
      check_sql!(sql)
      _execute_immediate(sql)
    end

    def execute_direct(sql)
      check_sql!(sql)
      _execute_direct(preprocess_sql(sql))
    end

    def prepare(sql)
      check_sql!(sql)
      _prepare(preprocess_sql(sql))
    end

    private

    def check_sql!(sql)
      raise SQLAnywhere2::Error, 'SQL must be a String' unless sql.is_a?(String)
      raise SQLAnywhere2::Error, 'SQL must not be empty' if sql.empty?
    end

    def preprocess_sql(sql)
      @enable_crash_fix ? "set @@sqlawnywhere2_fix = ''; #{sql}" : sql
    end

    def symbolize_opts_keys(opts)
      opts.each_with_object({}) { |(key, val), obj| obj[key.to_sym] = val }
    end

    def parse_conn_string(conn_string)
      conn_string.split(';').each_with_object({}) do |kv, obj|
        key, *value = kv.split('=')
        obj[key] = value.join('=')
      end
    end

    def build_conn_string(opts)
      opts.map { |key, val| "#{key}=#{val}" }.join(';')
    end
  end
end
