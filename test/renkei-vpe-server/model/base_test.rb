$: << File.join(File.dirname(__FILE__), '..', '..', '..', 'lib')

require 'test/unit'
require 'fileutils'
require 'pp'
require 'renkei-vpe-server/model/base'
require 'renkei-vpe-server/model/user'

#############################################################################
# Test for database
#############################################################################
log_file = 'rvped.log'
RenkeiVPE::Logger.init(log_file)

class DatabaseTest < Test::Unit::TestCase
  include RenkeiVPE
  @@db_file = 'rvped.db'
  @@user1 = 'oneadmin'
  @@user2 = 'shin'
  @@user3 = 'test'
  @@user4 = 'test2'
  @@user_sql1 = "INSERT INTO users VALUES (0, 0, '#{@@user1}', 1, 'tt ni');"
  @@user_sql2 = "INSERT INTO users VALUES (1, 1, '#{@@user2}', 1, 'tt');"
  @@user_sql3 = "INSERT INTO users VALUES (5, 5, '#{@@user3}', 1, '');"
  @@user_sql4 = "INSERT INTO users VALUES (6, 6, '#{@@user4}', 1, '');"

  def setup
    Database.file = @@db_file
    Model::User.create_table_if_necessary
    Database.execute(@@user_sql1)
    Database.execute(@@user_sql2)
    Database.execute(@@user_sql3)
    Database.execute(@@user_sql4)
  end

  def teardown
    FileUtils.rm_rf(@@db_file)
  end

  # Database.file
  def test_01_Database_file
    assert_equal(@@db_file, Database.file)
  end

  # Database.execute('INSERT ...')
  def test_02_execute_insert
    correct = "INSERT INTO users VALUES (7, 7, 'aaa', 1, 'tt ni');"
    wrong1  = "INSERT INTO users VALUES (8, 8, 'bbb', 1);"
    wrong2  = "INSERT INTO users VALUES (9, 9, 'ccc', 1 'tt ni');"
    assert_nothing_raised do
      Database.execute(correct)
    end
    assert_raise(SQLite3::SQLException) do
      Database.execute(wrong1)
    end
    assert_raise(SQLite3::SQLException) do
      Database.execute(wrong2)
    end
  end

  # Database.execute('SELECT ...')
  def test_03_execute_select
    sql = "SELECT COUNT(*) FROM users WHERE enabled=1"

    # no block
    row = Database.execute(sql)
    assert_equal(Array, row.class)
    assert_equal(1, row.size)
    assert_equal('4', row[0][0])

    # with block
    blk = lambda {
      result = nil
      Database.execute(sql) do |r|
        result = r[0]
      end
      result
    }
    assert_equal('4', blk.call)


    sql = "SELECT * FROM users WHERE enabled=1;"

    # no block
    row = Database.execute(sql)
    assert_equal(Array, row.class)
    assert_equal(4, row.size)

    # with block
    blk = lambda {
      result = []
      Database.execute(sql) do |r|
        result << r
      end
      result
    }
    assert_equal(4, blk.call.size)
  end

  # Database.transaction when success
  def test_04_transaction_success
    select = "SELECT * FROM users;"

    sql1 = "DELETE FROM users WHERE name='#{@@user1}';"
    sql2 = "DELETE FROM users WHERE name='#{@@user2}';"
    sql3 = "DELETE FROM users WHERE name='#{@@user3}';"
    sql4 = "DELETE FROM users WHERE name='#{@@user4}';"

    ary = [sql1, sql2, sql3, sql4]
    assert_nothing_raised do
      Database.transaction(sql1, sql2, sql3, sql4)
    end

    row = Database.execute(select)
    assert_equal(0, row.size)
  end

  # Database.transaction when fail
  def test_04_transaction_fail
    select = "SELECT * FROM users;"

    sql1 = "DELETE FROM users WHERE name='#{@@user1}';"
    sql2 = "DELETE FROM users WHERE name='#{@@user2}';"
    sql3 = "DELETE FROM user  WHERE name='#{@@user3}';"
    sql4 = "DELETE FROM users WHERE name='#{@@user4}';"

    ary = [sql1, sql2, sql3, sql4]
    assert_raise(SQLite3::SQLException) do
      Database.transaction(sql1, sql2, sql3, sql4)
    end

    row = Database.execute(select)
    assert_equal(4, row.size)
  end

end

FileUtils.rm_rf(log_file)


# Local Variables:
# mode: Ruby
# coding: utf-8-unix
# indent-tabs-mode: nil
# End:
