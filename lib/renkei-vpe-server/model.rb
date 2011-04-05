require 'rubygems'
require 'sqlite3'

module RenkeiVPE

  ############################################################################
  # a module that provides access to database
  ############################################################################
  module Database
    @@db_file = nil

    # set db file
    def file=(db_file)
      @@db_file = db_file
    end

    # get db file
    def file
      @@db_file
    end

    # execute +sql+ on database
    def execute(sql)
      begin
        db = SQLite3::Database.new(@@db_file)
        db.execute(sql) do |row|
          if block_given?
            yield row
          else
            return row
          end
        end
      ensure
        db.close
      end
    end

    # execute +sqls+ as a transaction on database
    def transaction(*sqls)
      begin
        db = SQLite3::Database.new(@@db_file)
        db.transaction do
          sqls.each do |sql|
            db.execute(sql)
          end
        end
      ensure
        db.close
      end
    end

    # initializate the database
    def init(db_file)
      Database.file = db_file

      Model::User.create_table_if_necessary
      Model::Zone.create_table_if_necessary
    end

    module_function :file=, :file, :execute, :transaction, :init
  end


  ############################################################################
  # A module whose classes store Renkei VPE data
  ############################################################################
  module Model

    ##########################################################################
    # Super class for all models
    ##########################################################################
    class BaseModel
      # name and schema of a table that stores instance of this model
      @table_name   = nil
      @table_schema = nil

      # id of instance of this model
      attr_reader :id

      # creates a record that represents this instance on the table.
      def create
        check_fields
        sql = "INSERT INTO #{table} VALUES (NULL,#{to_create_record_str})"
        Database.transaction(sql)
        sql = "SELECT id FROM #{table} WHERE #{to_find_id_str}"
        @id = Database.execute(sql)[0]
      end

      # updates a record that represents this instance on the table.
      def update
        check_fields
        sql = "UPDATE #{table} SET #{to_update_record_str} WHERE id=#{@id}"
        Database.transaction(sql)
      end

      # deletes a record that represents this instance from the table.
      def delete
        raise "'id' is not set." if @id == nil
        sql = "DELETE FROM #{table} WHERE id=#{@id}"
        Database.transaction(sql)
      end

      protected

      def table
        self.class.table_name
      end

      # It checks all fields.
      # Do nothing if all fields is fine, otherwise raise an excepton.
      def check_fields
        raise NotImplementedException
      end

      # It generates a string used in create record sql command.
      def to_create_record_str
        raise NotImplementedException
      end

      # It generates a string used to find id of the record from table.
      def to_find_id_str
        raise NotImplementedException
      end

      # It generates a string used in update record sql command.
      def to_update_record_str
        raise NotImplementedException
      end


      # It returns table name.
      def self.table_name
        @table_name
      end

      # It creates table on db.
      # return true if table is created, otherwise return false
      def self.create_table_if_necessary
        # check if table has been created
        sql = "SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='#{@table_name}'"
        Database.execute(sql) do |row|
          return false if row[0] != '0'
        end

        Database.transaction(@table_schema)
        return true
      end

      # It finds and returns records that match the given +condition+.
      # It return Array if found, otherwise return nil.
      def self.find(condition)
        sql = "SELECT * FROM #{@table_name} WHERE #{condition};"
        return Database.execute(sql)
      end
    end

    ##########################################################################
    # Model for Renkei VPE user
    ##########################################################################
    class User < BaseModel
      @table_name = 'users'

      @table_schema = <<SQL
CREATE TABLE #{@table_name} (
  id      INTEGER PRIMARY KEY AUTOINCREMENT,
  oid     INTEGER,
  name    VARCHAR(256),
  enabled INTEGER,
  zones   TEXT,

  UNIQUE(name)
);
SQL

      attr_accessor :oid, :name, :enabled, :zones

      protected

      def check_fields
        unless @oid
          raise "'oid' field must not be nil."
        end
        unless @oid.kind_of?(Integer)
          raise "'oid' must be an integer"
        end
        unless @name
          raise "'name' field must not be nil."
        end
        unless @name.instance_of?(String)
          raise "'name' must be a string"
        end
        unless @enabled
          raise "'enabled' field must not be nil."
        end
        unless @enabled.kind_of?(Integer)
          raise "'enabled' must be an integer"
        end
        unless @zones == nil || @zones.instance_of?(String)
          raise "'zones' must be nil or a string"
        end
      end

      def to_create_record_str
        "#{@oid},'#{@name}',#{@enabled},'#{@zones}'"
      end

      def to_find_id_str
        "name='#{@name}'"
      end

      def to_update_record_str
        "oid=#{@oid},name='#{@name}',enabled=#{@enabled},zones='#{@zones}'"
      end


      # It finds and returns a user whose id is +id+.
      # It returns nil if not found.
      def self.find_by_id(id)
        vals = User.find("id=#{id}")
        return nil unless vals

        u = User.new
        u.instance_eval do
          @id      = vals[0]
          @oid     = vals[1].to_i
          @name    = vals[2]
          @enabled = vals[3].to_i
          @zones   = vals[4]
        end
        return u
      end

      # It finds and returns a user whose name is +name+.
      # It returns nil if not found.
      def self.find_by_name(name)
        vals = User.find("name='#{name}'")
        return nil unless vals

        u = User.new
        u.instance_eval do
          @id      = vals[0]
          @oid     = vals[1].to_i
          @name    = vals[2]
          @enabled = vals[3].to_i
          @zones   = vals[4]
        end
        return u
      end

    end

    ##########################################################################
    # Model for Zone that means a site
    ##########################################################################
    class Zone < BaseModel
      @table_name = 'zones'

      @table_schema = <<SQL
CREATE TABLE #{@table_name} (
  id       INTEGER PRIMARY KEY AUTOINCREMENT,
  oid      INTEGER,
  name     VARCHAR(256),
  hosts   TEXT,
  networks TEXT,

  UNIQUE(name)
);
SQL

      attr_accessor :oid, :name, :hosts, :networks

      protected

      def check_fields
        unless @oid
          raise "'oid' field must not be nil."
        end
        unless @oid.kind_of?(Integer)
          raise "'oid' must be an integer"
        end
        unless @name
          raise "'name' field must not be nil."
        end
        unless @name.instance_of?(String)
          raise "'name' must be a string"
        end
        unless @hosts == nil || @hosts.instance_of?(String)
          raise "'hosts' must be nil or a string"
        end
        unless @networks == nil || @networks.instance_of?(String)
          raise "'networks' must be nil or a string"
        end
      end

      def to_create_record_str
        "#{@oid},'#{@name}','#{@hosts}','#{@networks}'"
      end

      def to_find_id_str
        "name='#{@name}'"
      end

      def to_update_record_str
        "oid=#{@oid},name='#{@name}',hosts='#{@hosts}',networks='#{@networks}'"
      end


      # It finds and returns a zone whose id is +id+.
      # It returns nil if not found.
      def self.find_by_id(id)
        vals = Zone.find("id=#{id}")
        return nil unless vals

        z = Zone.new
        z.instance_eval do
          @id       = vals[0]
          @oid      = vals[1].to_i
          @name     = vals[2]
          @hosts    = vals[3]
          @networks = vals[4]
        end
        return z
      end

      # It finds and returns a zone whose name is +name+.
      # It returns nil if not found.
      def self.find_by_name(name)
        vals = Zone.find("name='#{name}'")
        return nil unless vals

        z = Zone.new
        z.instance_eval do
          @id       = vals[0]
          @oid      = vals[1].to_i
          @name     = vals[2]
          @hosts    = vals[3]
          @networks = vals[4]
        end
        return z
      end
    end

  end
end


### test
if __FILE__ == $0
  require 'pp'
  require 'fileutils'
  require 'test/unit'

  class DatabaseTest < Test::Unit::TestCase
    include RenkeiVPE
    @@db_file = 'rvped.db'
    @@user1 = 'oneadmin'
    @@user2 = 'shin'
    @@user3 = 'test'
    @@user4 = 'test2'
    @@user_sql1 = "INSERT INTO users VALUES (0, 0, '#{@@user1}', 1, 'tt;ni');"
    @@user_sql2 = "INSERT INTO users VALUES (1, 1, '#{@@user2}', 1, 'tt;ni');"
    @@user_sql3 = "INSERT INTO users VALUES (5, 5, '#{@@user3}', 1, 'tt;ni');"
    @@user_sql4 = "INSERT INTO users VALUES (6, 6, '#{@@user4}', 1, 'tt;ni');"

    def setup
      FileUtils.rm_rf(@@db_file)

      Database.file = @@db_file
      Model::User.create_table_if_necessary
      Database.execute(@@user_sql1)
      Database.execute(@@user_sql2)
      Database.execute(@@user_sql3)
      Database.execute(@@user_sql4)
    end

    # Database.file
    def test_01
      assert_equal(@@db_file, Database.file)
    end

    # User.create_table_if_necessary
    def test_02
      assert_equal(false, Model::User.create_table_if_necessary)
    end

    # User.find_*
    def test_03
      assert_equal('oneadmin', Model::User.find_by_id(0).name)
      assert_equal('test',     Model::User.find_by_id(5).name)
      assert_nil(Model::User.find_by_id(3))

      assert_equal('oneadmin', Model::User.find_by_name(@@user1).name)
      assert_equal('test',     Model::User.find_by_name(@@user3).name)
      assert_nil(Model::User.find_by_name('unexist'))
    end

    # User.check_fields
    def test_04
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
    def test_05
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
      assert_equal(u.name, Model::User.find_by_id(u.id).name)
    end

    # User.delete
    def test_06
      assert_raise(RuntimeError) do
        u = Model::User.new
        # u.id is not set
        u.delete
      end

      u = Model::User.find_by_name(@@user3)
      assert_nothing_raised { u.delete }
      assert_nil(Model::User.find_by_name(@@user3))
    end

    # User.update
    def test_07
      u = Model::User.find_by_name(@@user3)
      u.enabled = nil
      assert_raise(RuntimeError) do
        # u.enabled is nil
        u.update
      end

      new_zones = 'tt;ni;os'
      u = Model::User.find_by_name(@@user3)
      u.zones = new_zones
      assert_nothing_raised { u.update }
      assert_equal(new_zones, Model::User.find_by_name(@@user3).zones)
    end
  end
end


# Local Variables:
# mode: Ruby
# coding: utf-8-unix
# indent-tabs-mode: nil
# End:
