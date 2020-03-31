# frozen_string_literal: true

module SQLAnywhere2
  class Error < StandardError
    ENCODE_OPTS = {
      undef: :replace,
      invalid: :replace,
      replace: '?'
    }.freeze

    attr_reader :error_number, :sql_state

    def initialize(msg, error_number = nil, sql_state = nil)
      @error_number = error_number
      @sql_state = sql_state ? sql_state.encode(**ENCODE_OPTS) : nil

      super(msg.encode(**ENCODE_OPTS))
    end
  end
end
