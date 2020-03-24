# frozen_string_literal: true

module SQLAnywhere2
  Column = Struct.new(:name, :type, :native_type, :precision, :scale, :max_size, :nullable) do
    private_class_method :new # This is can only be called natively in C land
  end
end
