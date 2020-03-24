# frozen_string_literal: true

require './spec/spec_helper.rb'

RSpec.describe SQLAnywhere2::Result do
  let!(:connection) { new_connection }

  it 'should not allow initialization' do
    expect { SQLAnywhere2::Result.new }.to raise_error(NoMethodError)
  end

  it 'should have included Enumerable' do
    expect(SQLAnywhere2::Result.ancestors.include?(Enumerable)).to be true
  end

  it 'should respond to #count' do
    _, result = connection.execute_direct('SELECT 1')
    expect(result).to respond_to :count
  end

  context '#rows' do
    it 'should return an array of values in proper order' do
      _, result = connection.execute_direct('SELECT 1, 2, 3')
      expect(result.rows.length).to eq(1)
      expect(result.rows.first).to eql([1, 2, 3])
    end
  end

  context '#columns' do
    it 'should return an array of columns in proper order' do
      _, result = connection.execute_direct('SELECT 1 "a", 2 "b", 3 "c"')
      expect(result.columns.map(&:name)).to eql(%w[a b c])
    end
  end

  context '#each' do
    it 'should yield rows' do
      _, result = connection.execute_direct('SELECT 1, 2, 3')

      result.each do |row|
        expect(row).to be_an_instance_of(Array)
      end
    end
  end
end
