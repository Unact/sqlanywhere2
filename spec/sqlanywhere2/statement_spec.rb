# frozen_string_literal: true

require './spec/spec_helper.rb'

RSpec.describe SQLAnywhere2::Statement do
  let!(:connection) { new_connection }
  let(:binary_test_val) { [0x78] }
  let(:decimal_test_val) { 1.1 }
  let(:string_test_val) { 'String Test' }
  let(:bigint_test_val) { 9_223_372_036_854_775_807 }
  let(:unsigned_bigint_test_val) { 18_446_744_073_709_551_615 }
  let(:integer_test_val) { 2_147_483_647 }
  let(:unsigned_integer_test_val) { 4_294_967_295 }
  let(:smallint_test_val) { 32_767 }
  let(:unsigned_smallint_test_val) { 65_535 }
  let(:tinyint_test_val) { 255 }
  let(:unsigned_tinyint_test_val) { 255 }
  let(:bit_test_val) { true }
  let(:date_test_val) { Date.new(1999, 1, 2) }
  let(:datetime_test_val) { Time.new(1999, 1, 2, 21, 20, 53) }
  let(:double_test_val) { 1.79769313486231e+308 }
  let(:float_test_val) { 3.402823e+38 }
  let(:real_test_val) { 3.402823e+38 }

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

      expect(first_row[1].unpack('c*')).to eq(binary_test_val)
      expect(first_row[2].unpack('c*')).to eq(binary_test_val)
      expect(first_row[3]).to eq(decimal_test_val)
      expect(first_row[4]).to eq(decimal_test_val)
      expect(first_row[5]).to eq(string_test_val)
      expect(first_row[6]).to eq(string_test_val)
      expect(first_row[7]).to eq(bigint_test_val)
      expect(first_row[8]).to eq(unsigned_bigint_test_val)
      expect(first_row[9]).to eq(integer_test_val)
      expect(first_row[10]).to eq(unsigned_integer_test_val)
      expect(first_row[11]).to eq(smallint_test_val)
      expect(first_row[12]).to eq(unsigned_smallint_test_val)
      expect(first_row[13]).to eq(tinyint_test_val)
      expect(first_row[14]).to eq(unsigned_tinyint_test_val)
      expect(first_row[15]).to eq(bit_test_val)
      expect(first_row[16]).to eq(date_test_val)
      expect(first_row[17]).to eq(datetime_test_val)
      expect(first_row[18]).to eq(datetime_test_val)
      expect(first_row[19]).to eq(datetime_test_val)
      expect(first_row[20]).to be_within(1e+308).of(double_test_val)
      expect(first_row[21]).to be_within(1e+38).of(float_test_val)
      expect(first_row[22]).to be_within(1e+38).of(real_test_val)
    end

    context 'bind types' do
      it 'should bind BINARY correctly' do
        statement = connection.prepare('SELECT CAST(? AS BINARY)')

        result = statement.execute(binary_test_val.pack('c*'))
        expect(result.first[0].unpack('c*')).to eq(binary_test_val)
      end

      it 'should bind LONG BINARY correctly' do
        statement = connection.prepare('SELECT CAST(? AS LONG BINARY)')

        result = statement.execute(binary_test_val.pack('c*'))

        expect(result.first[0].unpack('c*')).to eq(binary_test_val)
      end

      it 'should bind NUMERIC correctly' do
        statement = connection.prepare('SELECT CAST(? AS NUMERIC(2,1))')

        result = statement.execute(decimal_test_val)

        expect(result.first[0]).to eq(decimal_test_val)
      end

      it 'should bind DECIMAL correctly' do
        statement = connection.prepare('SELECT CAST(? AS DECIMAL(2,1))')

        result = statement.execute(decimal_test_val)

        expect(result.first[0]).to eq(decimal_test_val)
      end

      it 'should bind VARCHAR correctly' do
        statement = connection.prepare('SELECT CAST(? AS VARCHAR(255)) S')

        result = statement.execute(string_test_val)
        expect(result.first[0]).to eq(string_test_val)
      end

      it 'should bind LONG VARCHAR correctly' do
        statement = connection.prepare('SELECT CAST(? AS LONG VARCHAR) S')

        result = statement.execute(string_test_val)
        expect(result.first[0]).to eq(string_test_val)
      end

      it 'should bind BIGINT correctly' do
        statement = connection.prepare('SELECT CAST(? AS BIGINT) S')

        result = statement.execute(bigint_test_val)
        expect(result.first[0]).to eq(bigint_test_val)
      end

      it 'should bind UNSIGNED BIGINT correctly' do
        statement = connection.prepare('SELECT CAST(? AS UNSIGNED BIGINT) S')

        result = statement.execute(unsigned_bigint_test_val)
        expect(result.first[0]).to eq(unsigned_bigint_test_val)
      end

      it 'should bind INTEGER correctly' do
        statement = connection.prepare('SELECT CAST(? AS INTEGER) S')

        result = statement.execute(integer_test_val)
        expect(result.first[0]).to eq(integer_test_val)
      end

      it 'should bind UNSIGNED INTEGER correctly' do
        statement = connection.prepare('SELECT CAST(? AS UNSIGNED INTEGER) S')

        result = statement.execute(unsigned_integer_test_val)
        expect(result.first[0]).to eq(unsigned_integer_test_val)
      end

      it 'should bind SMALLINT correctly' do
        statement = connection.prepare('SELECT CAST(? AS SMALLINT) S')

        result = statement.execute(smallint_test_val)
        expect(result.first[0]).to eq(smallint_test_val)
      end

      it 'should bind UNSIGNED SMALLINT correctly' do
        statement = connection.prepare('SELECT CAST(? AS UNSIGNED SMALLINT) S')

        result = statement.execute(unsigned_smallint_test_val)
        expect(result.first[0]).to eq(unsigned_smallint_test_val)
      end

      it 'should bind TINYINT correctly' do
        statement = connection.prepare('SELECT CAST(? AS TINYINT) S')

        result = statement.execute(tinyint_test_val)
        expect(result.first[0]).to eq(tinyint_test_val)
      end

      it 'should bind UNSIGNED TINYINT correctly' do
        statement = connection.prepare('SELECT CAST(? AS UNSIGNED TINYINT) S')

        result = statement.execute(unsigned_tinyint_test_val)
        expect(result.first[0]).to eq(unsigned_tinyint_test_val)
      end

      it 'should bind BIT correctly' do
        statement = connection.prepare('SELECT CAST(? AS BIT) S')

        result = statement.execute(bit_test_val ? 1 : 0)
        expect(result.first[0]).to eq(bit_test_val)
      end

      it 'should bind DATE correctly' do
        statement = connection.prepare('SELECT CAST(? AS DATE)')

        result = statement.execute(date_test_val.to_s)

        expect(result.first[0]).to eq(date_test_val)
      end

      it 'should bind DATETIME correctly' do
        statement = connection.prepare('SELECT CAST(? AS DATETIME)')

        result = statement.execute(datetime_test_val.to_s)

        expect(result.first[0]).to eq(datetime_test_val)
      end

      it 'should bind SMALLDATETIME correctly' do
        statement = connection.prepare('SELECT CAST(? AS SMALLDATETIME)')

        result = statement.execute(datetime_test_val.to_s)

        expect(result.first[0]).to eq(datetime_test_val)
      end

      it 'should bind TIMESTAMP correctly' do
        statement = connection.prepare('SELECT CAST(? AS TIMESTAMP)')

        result = statement.execute(datetime_test_val.to_s)

        expect(result.first[0]).to eq(datetime_test_val)
      end

      it 'should bind DOUBLE correctly' do
        statement = connection.prepare('SELECT CAST(? AS DOUBLE) S')

        result = statement.execute(double_test_val)
        expect(result.first[0]).to be_within(1e+308).of(double_test_val)
      end

      it 'should bind FLOAT correctly' do
        statement = connection.prepare('SELECT CAST(? AS FLOAT) S')

        result = statement.execute(float_test_val)
        expect(result.first[0]).to be_within(1e+38).of(float_test_val)
      end

      it 'should bind REAL correctly' do
        statement = connection.prepare('SELECT CAST(? AS REAL) S')

        result = statement.execute(real_test_val)
        expect(result.first[0]).to be_within(1e+38).of(real_test_val)
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

    it 'rows should return array even if no rows are returned' do
      statement = connection.prepare('DECLARE @TEST INT')
      result = statement.execute

      expect(result.count).to eq(0)
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
