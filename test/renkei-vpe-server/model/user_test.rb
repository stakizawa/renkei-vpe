$: << File.join(File.dirname(__FILE__), '..', '..', '..', 'lib')

require 'test/unit'
require 'fileutils'
require 'pp'
require 'renkei-vpe-server/model/base'
require 'renkei-vpe-server/model/user'

#############################################################################
# Test for User model
#############################################################################
log_file = 'rvped.log'
RenkeiVPE::Logger.init(log_file)

class UserTest < Test::Unit::TestCase
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
  end

  def teardown
    FileUtils.rm_rf(@@db_file)
  end

  def add_users
    Database.execute(@@user_sql1)
    Database.execute(@@user_sql2)
    Database.execute(@@user_sql3)
    Database.execute(@@user_sql4)
  end

  # User.table_name
  def test_01_User_table_name
    assert_equal('users', Model::User.table_name)
  end

  # User.create_table_if_necessary
  def test_02_User_create_table_if_necessary
    assert_equal(false, Model::User.create_table_if_necessary)
  end

  # User.find_*
  def test_03_User_find
    add_users

    us = Model::User.find_by_id(0)
    assert_equal(Array, us.class)
    assert_equal('oneadmin', us[0].name)

    assert_equal([], Model::User.find_by_id(3))

    us = Model::User.find_by_name(@@user1)
    assert_equal(Array, us.class)
    assert_equal('oneadmin', us[0].name)

    assert_equal([], Model::User.find_by_name('unexist'))
  end

  # check_fields
  def test_03
    u = Model::User.new
    assert_raise(RuntimeError) do
      u.instance_eval do
        check_fields
      end
    end

    u.name = @@user3
    assert_raise(RuntimeError) do
      u.instance_eval do
        check_fields
      end
    end

    u.enabled = 'testval'
    assert_raise(RuntimeError) do
      u.instance_eval do
        check_fields
      end
    end

    u.oid = 9
    u.enabled = 1
    assert_nothing_raised do
      u.instance_eval do
        check_fields
      end
    end
  end

  # User.create
  def test_04
    add_users
    u = Model::User.new

    u.oid = 10
    u.enabled = 1
    assert_raise(RuntimeError) do
      # u.name is unset
      u.create
    end

    u.name = @@user3
    assert_raise(SQLite3::SQLException) do
      # u.name is conflict
      u.create
    end

    u.name = 'testtest'
    assert_nothing_raised { u.create }
    this_u = Model::User.find_by_id(u.id)
    assert_equal(1, this_u.size)
    assert_equal(u.name, this_u[0].name)
  end

  # User.delete
  def test_05
    add_users
    assert_raise(RuntimeError) do
      u = Model::User.new
      # u.id is not set
      u.delete
    end

    u = Model::User.find_by_name(@@user3)[0]
    assert_nothing_raised { u.delete }
    assert_equal([], Model::User.find_by_name(@@user3))
  end

  # User.update
  def test_06
    add_users
    u = Model::User.find_by_name(@@user3)[0]
    u.enabled = nil
    assert_raise(RuntimeError) do
      # u.enabled is nil
      u.update
    end

    new_zones = 'tt ni os'
    u = Model::User.find_by_name(@@user3)[0]
    u.zones = new_zones
    assert_nothing_raised { u.update }
    assert_equal(new_zones, Model::User.find_by_name(@@user3)[0].zones)
  end
end

FileUtils.rm_rf(log_file)


# Local Variables:
# mode: Ruby
# coding: utf-8-unix
# indent-tabs-mode: nil
# End:
