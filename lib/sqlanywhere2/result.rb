# frozen_string_literal: true

module SQLAnywhere2
  class Result
    include Enumerable

    attr_reader :columns, :rows
    private_class_method :new # This is can only be called natively in C land

    def initialize(columns, rows)
      @columns = columns
      @rows = rows
    end

    def each(&block)
      if block_given?
        @rows.each(&block) if @rows
      else
        to_enum(:each)
      end
    end
  end
end
