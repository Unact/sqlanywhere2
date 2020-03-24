# frozen_string_literal: true

require './spec/spec_helper.rb'

RSpec.describe SQLAnywhere2::Statement do
  let!(:connection) { new_connection }

  it 'should not allow initialization' do
    expect { SQLAnywhere2::Statement.new }.to raise_error(NoMethodError)
  end

  it 'should create a statement' do
    statement = connection.prepare('SELECT 1')
    expect(statement).to be_an_instance_of(SQLAnywhere2::Statement)
  end

  context '#num_params' do
    it 'should tell us the param count' do
      statement = connection.prepare('SELECT ?, ?')
      expect(statement.num_params).to eq(2)

      statement2 = connection.prepare('SELECT 1')
      expect(statement2.num_params).to eq(0)
    end
  end

  context '#num_columns' do
    it 'should tell us the column count' do
      statement = connection.prepare('SELECT ?, ?')
      expect(statement.num_columns).to eq(2)

      statement2 = connection.prepare('SELECT 1')
      expect(statement2.num_columns).to eq(1)
    end
  end

  context '#execute' do
    it 'should create a result' do
      statement = connection.prepare('SELECT 1')
      expect(statement.execute).to be_an_instance_of(SQLAnywhere2::Result)
    end

    it 'should return an error when number of bound params is different from execution params' do
      statement = connection.prepare('SELECT TOP ? 1')
      expect { statement.execute }.to raise_error(SQLAnywhere2::Error)
    end

    it 'should correctly retrieve types' do
      statement = connection.prepare('SELECT * FROM sqlanywhere2_test')
      result = statement.execute
      first_row = result.first

      expect(first_row[0]).to eq(0)
      expect(first_row[1].unpack('c*').first.to_i).to eq(0x78)
      expect(first_row[2]).to eq(1.1)
      expect(first_row[3]).to eq(1.1)
      expect(first_row[4]).to eq('Bounded String Test')
      expect(first_row[5]).to eq('Unbounded String Test')
      expect(first_row[6]).to eq(9_223_372_036_854_775_807)
      expect(first_row[7]).to eq(18_446_744_073_709_551_615)
      expect(first_row[8]).to eq(2_147_483_647)
      expect(first_row[9]).to eq(4_294_967_295)
      expect(first_row[10]).to eq(32_767)
      expect(first_row[11]).to eq(65_535)
      expect(first_row[12]).to eq(255)
      expect(first_row[13]).to eq(255)
      expect(first_row[14]).to eq(true)
      expect(first_row[15]).to eq(Date.new(1999, 1, 2))
      expect(first_row[16]).to eq(Time.new(1999, 1, 2, 21, 20, 53))
      expect(first_row[17]).to eq(Time.new(1999, 1, 2, 21, 20, 53))
      expect(first_row[18]).to eq(Time.new(1999, 1, 2, 21, 20, 53))
      expect(first_row[19]).to be_within(1e+308).of(1.79769313486231e+308)
      expect(first_row[20]).to be_within(1e+38).of(3.402823e+38)
      expect(first_row[21]).to be_within(1e+38).of(3.402823e+38)
    end

    context 'bind types' do
      it 'should bind BINARY correctly' do
        val = [1, 2]
        statement = connection.prepare('SELECT CAST(? AS BINARY)')

        result = statement.execute(val.pack('c*'))
        expect(result.first[0].unpack('c*')).to eq(val)
      end

      it 'should bind STRING correctly' do
        val = 'STR'
        statement = connection.prepare('SELECT CAST(? AS LONG VARCHAR) S')

        result = statement.execute(val)
        expect(result.first[0]).to eq(val)
      end

      it 'should bind FIXNUM correctly' do
        val = 1
        statement = connection.prepare('SELECT CAST(? AS INT) S')

        result = statement.execute(val)
        expect(result.first[0]).to eq(val)
      end

      it 'should bind BIGNUM correctly' do
        val = 2**62
        statement = connection.prepare('SELECT CAST(? AS BIGINT) S')

        result = statement.execute(val)
        expect(result.first[0]).to eq(val)
      end

      it 'should bind FLOAT correctly' do
        val = 2.01
        statement = connection.prepare('SELECT CAST(? AS FLOAT) S')

        result = statement.execute(val)
        expect(result.first[0]).to be_within(1e-5).of(val)
      end

      it 'should bind NIL correctly' do
        val = nil
        statement = connection.prepare('SELECT ? S')

        result = statement.execute(val)
        expect(result.first[0]).to eq(val)
      end

      it 'should raise error if type is not supported' do
        val = Time.now
        statement = connection.prepare('SELECT ? S')

        expect { statement.execute(val) }.to raise_error(TypeError)
      end
    end
  end

  context '#last_result' do
    it 'should return last stored result for a prepared statement' do
      statement = connection.prepare('SELECT 1')
      result = statement.execute

      expect(result).to eq(statement.last_result)
    end

    it 'should return last stored result for a execute_direct statement' do
      statement, result = connection.execute_direct('SELECT 1')

      expect(result).to eq(statement.last_result)
    end
  end

  context '#close' do
    it 'should close statement' do
      statement = connection.prepare('SELECT 1')

      statement.close

      expect { statement.execute }.to raise_error(SQLAnywhere2::Error)
    end
  end

  context '#affected_rows' do
    it 'should return number of affected rows' do
      statement = connection.prepare('UPDATE sqlanywhere2_test SET id = 1')

      statement.execute

      expect(statement.affected_rows).to eq(1)
    end
  end

  context '#columns' do
    it 'should return an array of SQLAnywhere2::Column' do
      statement = connection.prepare('SELECT 1')
      columns = statement.columns

      expect(columns.length).to eq(1)
      expect(columns.first).to be_an_instance_of(SQLAnywhere2::Column)
      expect(columns.first.name).to eq('1')
    end
  end
end
