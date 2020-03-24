# frozen_string_literal: true

module SQLAnywhere2
  class Error < StandardError
    attr_reader :error_number, :sql_state

    def initialize(msg, error_number = nil, sql_state = nil)
      @error_number = error_number
      @sql_state = sql_state

      super(msg)
    end
  end
end
