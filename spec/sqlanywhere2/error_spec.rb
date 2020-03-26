# frozen_string_literal: true

require './spec/spec_helper.rb'

RSpec.describe SQLAnywhere2::Error do
  let!(:connection) { new_connection }
  let(:test_query) { 'SUCH ERROR MUCH WOW' }

  def create_error(query)
    begin
      connection.execute_immediate(query)
    rescue SQLAnywhere2::Error => e
      error = e
    end

    error
  end

  it 'responds to error_number and sql_state' do
    error = create_error(test_query)

    expect(error).to respond_to(:error_number)
    expect(error).to respond_to(:sql_state)
  end

  context 'encoding' do
    let(:invalid_message_encoding) { ['e5c67d1f'].pack('H*').force_encoding(connection.encoding) }
    let(:valid_message_encoding) { '文字' }

    it 'should form valid message for incorrectly encoded value' do
      error = create_error("raiserror 55555 '#{invalid_message_encoding}'")

      expect(error.message).to be_valid_encoding
      expect(error.message.encoding.name).to eq(connection.encoding)
    end

    it 'should form valid message for correctly encoded value' do
      error = create_error("raiserror 55555 '#{valid_message_encoding}'")

      expect(error.message).to be_valid_encoding
      expect(error.message.encoding.name).to eq(connection.encoding)
    end
  end
end
