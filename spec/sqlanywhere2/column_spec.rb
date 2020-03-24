# frozen_string_literal: true

require './spec/spec_helper.rb'

RSpec.describe SQLAnywhere2::Column do
  it 'should not allow initialization' do
    expect { SQLAnywhere2::Column.new }.to raise_error(NoMethodError)
  end
end
