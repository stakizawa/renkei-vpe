require 'rubygems'
require 'sqlite3'

module RenkeiVPE
  ###########################################################################
  # A module whose classes store user data
  ###########################################################################
  module Database

    #########################################################################
    # A class that defines table schame
    #########################################################################
    class TableSchema
      # sqlite3 database file path
      @@db_file = nil

      # delete existing methods
      instance_methods.each do |m|
        undef_method m unless m.to_s =~ /^__|method_missing|respond_to?/
      end

      def initialize(name)
        @name  = name
        @attr_keys = []
        @attrs = {}
        @opts  = []
      end

      # It creates this table on db.
      def create
        schema = "CREATE TABLE #{@name} ("
        @attr_keys.each do |attr|
          schema += "#{attr} #{@attrs[attr]},"
        end
        @opts.each do |opt|
          schema += "#{opt},"
        end
        schema.chop!     # remove ','
        schema += ");"

        puts schema
        db_transaction(schema)
      end

      # It inserts a record represented in +str+ into this table.
      def insert(str)
        sql = "insert into #{@name} values (#{str})"
        db_transaction(sql)
      end

      # It finds +target+ column value that matches +condition+ condition.
      # +return+  array of results
      def find(target, condition)
        sql = "select #{target} from #{@name} where #{condition}"
        db_execute(sql)
      end

      # It returns true if specified table exists, otherwise false.
      def check_if_created
        sql = "select count(*) from sqlite_master where type='table' AND name='#{@name}'"
        db_execute(sql) do |row|
          return true if row[0] != '0'
          return false
        end
      end

      # It adds options to table schema.
      def add_option(option)
        @opts << option
      end

      def method_missing(name, *args)
        unless @attrs[name]
          @attr_keys << name
          @attrs[name] = args[0]
        else # already exists
          raise "table attribute is already defined: #{name}"
        end
      end

      # It defines a named table.
      def self.define_table(name)
        table = TableSchema.new(name)
        yield table
        return table
      end

      def self.db_file=(file)
        @@db_file = file
      end

      def self.db_file
        @@db_file
      end

    private

      def db_execute(sql)
        begin
          db = SQLite3::Database.new(@@db_file)
          db.execute(sql) do |raw|
            if block_given?
              yield raw
            else
              return raw
            end
          end
        ensure
          db.close
        end
      end

      def db_transaction(*sqls)
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

    end


    #########################################################################
    # Define tables
    #########################################################################
    Users = TableSchema.define_table('users') do |t|
      t.id      'INTEGER PRIMARY KEY'
      t.name    'VARCHAR(256)'
      t.enabled 'INTEGER'
      t.zones   'TEXT'

      t.add_option('UNIQUE(name)')
    end

    Tables = [
              Users
             ]


    def init(db_file)
      TableSchema.db_file = db_file

      Tables.each do |t|
        t.create unless t.check_if_created
      end
    end
    module_function :init

  end
end


# Local Variables:
# mode: Ruby
# coding: utf-8
# indent-tabs-mode: nil
# End:
