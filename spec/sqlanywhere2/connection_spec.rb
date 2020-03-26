# frozen_string_literal: true

require './spec/spec_helper.rb'

RSpec.describe SQLAnywhere2::Connection do
  context '#initialize' do
    context ':encoding' do
      it 'should not initialize when encoding is not found' do
        expect { new_connection(encoding: 'ENC') }.to raise_error(ArgumentError)
      end

      it 'should prioritize encoding from conn_string' do
        conn_string = 'DatabaseName=test;UserID=dba;Password=sql;ConnectionName=test;Language=EN;CharSet=UTF-8'
        connection = new_connection(conn_string: conn_string, encoding: 'Windows-1251')

        expect(connection.encoding).to eq('UTF-8')
      end

      it 'should return result with selected encoding' do
        connection = new_connection(encoding: 'Windows-1251')
        _, result = connection.execute_direct("SELECT 'ASD'")

        expect(result.first[0].encoding.name).to eq('Windows-1251')
      end
    end

    context ':database_timezone' do
      it 'should default to :local data' do
        connection = new_connection

        expect(connection.database_timezone).to eq(:local)
      end

      it 'should raise error when :database_timezone not :local/:utc' do
        expect { new_connection(database_timezone: :test) }.to raise_error(SQLAnywhere2::Error)
      end

      it 'should allow :utc option' do
        connection = new_connection(database_timezone: :utc)

        expect(connection.database_timezone).to eq(:utc)
      end
    end

    context ':cast' do
      it 'should not cast values if disabled' do
        _, result = new_connection(cast: false).execute_direct('SELECT * FROM sqlanywhere2_test')

        first_row = result.first

        expect(first_row[3]).to eq('1.1')
        expect(first_row[4]).to eq('1.1')
        expect(first_row[15]).to eq(1)
        expect(first_row[16]).to eq('1999-01-02')
        expect(first_row[17]).to eq('1999-01-02 21:20:53.000')
        expect(first_row[18]).to eq('1999-01-02 21:20:53.000')
        expect(first_row[19]).to eq('1999-01-02 21:20:53.000')
      end
    end

    context ':enable_crash_fix' do
      let(:connection) { new_connection(enable_crash_fix: true) }

      it '#execute_direct should not crash' do
        expect(connection.execute_direct('CALL test(1)')).not_to be_nil
      end

      it 'prepared statement should not crash' do
        statement = connection.prepare('CALL test(1)')
        expect(statement.execute).not_to be_nil
      end
    end
  end

  context '#execute_immediate' do
    let(:connection) { new_connection }

    it 'should execute statement' do
      connection.execute_immediate('UPDATE sqlanywhere2_test SET id = 1')
      _, result = connection.execute_direct('SELECT id FROM sqlanywhere2_test')

      expect(result.first[0]).to eq(1)
    end

    it 'should raise an error if sql is empty' do
      expect { connection.execute_immediate('') }.to raise_error(SQLAnywhere2::Error)
    end

    it 'should raise an error if sql is nil' do
      expect { connection.execute_immediate(nil) }.to raise_error(SQLAnywhere2::Error)
    end
  end

  context '#execute_direct' do
    let(:connection) { new_connection }

    it 'should execute statement' do
      statement, result = connection.execute_direct('SELECT id FROM sqlanywhere2_test')

      expect(statement).to be_an_instance_of(SQLAnywhere2::Statement)
      expect(result).to be_an_instance_of(SQLAnywhere2::Result)
    end

    it 'should raise an error if sql is empty' do
      expect { connection.execute_direct('') }.to raise_error(SQLAnywhere2::Error)
    end

    it 'should raise an error if sql is nil' do
      expect { connection.execute_direct(nil) }.to raise_error(SQLAnywhere2::Error)
    end
  end

  context '#prepare' do
    let(:connection) { new_connection }

    it 'should create a statement' do
      statement = connection.prepare('SELECT id FROM sqlanywhere2_test')

      expect(statement).to be_an_instance_of(SQLAnywhere2::Statement)
    end

    it 'should raise an error if sql is empty' do
      expect { connection.prepare('') }.to raise_error(SQLAnywhere2::Error)
    end

    it 'should raise an error if sql is nil' do
      expect { connection.prepare(nil) }.to raise_error(SQLAnywhere2::Error)
    end
  end

  context '#commit' do
    let(:connection) { new_connection }

    it 'should commit result if successful' do
      connection.execute_direct('INSERT INTO sqlanywhere2_test(id) VALUES(2)')
      commit_result = connection.commit

      _, result = new_connection.execute_direct('SELECT * FROM sqlanywhere2_test WHERE id = 2')
      expect(commit_result).to eq(true)
      expect(result.first).not_to be_nil
    end

    it 'should not commit result if not successful' do
      connection.execute_direct('INSERT INTO sqlanywhere2_test(id) VALUES(2)')
      connection.close
      commit_result = connection.commit

      _, result = new_connection.execute_direct('SELECT * FROM sqlanywhere2_test WHERE id = 2')
      expect(commit_result).to eq(false)
      expect(result.first).to be_nil
    end
  end

  context '#commit!' do
    let(:connection) { new_connection }

    it 'should commit result if successful' do
      connection.execute_direct('INSERT INTO sqlanywhere2_test(id) VALUES(2)')
      commit_result = connection.commit!

      _, result = new_connection.execute_direct('SELECT * FROM sqlanywhere2_test WHERE id = 2')
      expect(commit_result).to eq(true)
      expect(result.first).not_to be_nil
    end

    it 'should not commit result and raise an error if not successful' do
      connection.execute_direct('INSERT INTO sqlanywhere2_test(id) VALUES(2)')
      connection.close

      expect { connection.commit! }.to raise_error(SQLAnywhere2::Error)

      _, result = new_connection.execute_direct('SELECT * FROM sqlanywhere2_test WHERE id = 2')
      expect(result.first).to be_nil
    end
  end

  context '#rollback' do
    let(:connection) { new_connection }

    it 'should rollback result if successful' do
      connection.execute_direct('INSERT INTO sqlanywhere2_test(id) VALUES(2)')
      rollback_result = connection.rollback

      _, result = new_connection.execute_direct('SELECT * FROM sqlanywhere2_test WHERE id = 2')
      expect(rollback_result).to eq(true)
      expect(result.first).to be_nil
    end

    it 'should return false if failed' do
      connection.execute_direct('INSERT INTO sqlanywhere2_test(id) VALUES(2)')
      connection.close
      rollback_result = connection.rollback

      _, result = new_connection.execute_direct('SELECT * FROM sqlanywhere2_test WHERE id = 2')
      expect(rollback_result).to eq(false)
      expect(result.first).to be_nil
    end
  end

  context '#rollback!' do
    let(:connection) { new_connection }

    it 'should rollback result if successful' do
      connection.execute_direct('INSERT INTO sqlanywhere2_test(id) VALUES(2)')
      rollback_result = connection.rollback!

      _, result = new_connection.execute_direct('SELECT * FROM sqlanywhere2_test WHERE id = 2')
      expect(rollback_result).to eq(true)
      expect(result.first).to be_nil
    end

    it 'should raise an error if not successful' do
      connection.execute_direct('INSERT INTO sqlanywhere2_test(id) VALUES(2)')
      connection.close

      expect { connection.rollback! }.to raise_error(SQLAnywhere2::Error)

      _, result = new_connection.execute_direct('SELECT * FROM sqlanywhere2_test WHERE id = 2')
      expect(result.first).to be_nil
    end
  end
end
