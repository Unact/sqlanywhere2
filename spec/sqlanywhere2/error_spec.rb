# frozen_string_literal: true

require './spec/spec_helper.rb'

RSpec.describe SQLAnywhere2::Error do
  let!(:connection) { new_connection }
  let!(:error) do
    begin
      connection.execute_immediate('SUCH ERROR MUCH WOW')
    rescue SQLAnywhere2::Error => e
      error = e
    end

    error
  end

  it 'responds to error_number and sql_state' do
    expect(error).to respond_to(:error_number)
    expect(error).to respond_to(:sql_state)
  end
end
