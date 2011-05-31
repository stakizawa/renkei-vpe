require 'renkei-vpe-server/logger'
require 'renkei-vpe-server/one_client'
require 'rubygems'
require 'sqlite3'
require 'rexml/document'

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
        if block_given?
          db.execute(sql) do |row|
            yield row
          end
        else
          return db.execute(sql)
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

    module_function :file=, :file, :execute, :transaction
  end


  ############################################################################
  # A module whose classes store Renkei VPE data
  ############################################################################
  module Model

    ##########################################################################
    # A module that overwite attr_accessor and attr_writer
    ##########################################################################
    module EnhancedAttributes
      def self.included(base)
        base.extend ClassMethods
      end

      module ClassMethods
        def attr_accessor(attr, &block)
          define_method "#{attr}=" do |val|
            val = block.call(val) if block_given?
            instance_variable_set("@#{attr}", val)
          end

          define_method attr do
            instance_variable_get("@#{attr}")
          end
        end

        def attr_writer(attr, &block)
          define_method "#{attr}=" do |val|
            val = block.call(val) if block_given?
            instance_variable_set("@#{attr}", val)
          end
        end

      end
    end

    ##########################################################################
    # Super class for all models
    ##########################################################################
    class BaseModel
      include RenkeiVPE::Const
      include EnhancedAttributes
      include RenkeiVPE::OpenNebulaClient

      # name and schema of a table that stores instance of this model
      @table_name   = nil
      @table_schema = nil

      # table field name used in self.find_by_name
      @field_for_find_by_name = nil

      # id of instance of this model
      attr_reader :id do |v|
        v.to_i
      end

      def initialize
        @log = RenkeiVPE::Logger.get_logger
      end

      # creates a record that represents this instance on the table.
      def create
        check_fields
        sql = "INSERT INTO #{table} VALUES (NULL,#{to_create_record_str})"
        Database.transaction(sql)
        sql = "SELECT id FROM #{table} WHERE #{to_find_id_str}"
        @id = Database.execute(sql).last[0]
        @log.debug "Record[#{self}] is added to Table[#{table}]"
      end

      # updates a record that represents this instance on the table.
      def update
        check_fields
        sql = "UPDATE #{table} SET #{to_update_record_str} WHERE id=#{@id}"
        Database.transaction(sql)
        @log.debug "Record[#{self}] is updated on Table[#{table}]"
      end

      # deletes a record that represents this instance from the table.
      def delete
        raise "'id' is not set." if @id == nil
        sql = "DELETE FROM #{table} WHERE id=#{@id}"
        Database.transaction(sql)
        @log.debug "Record[#{self}] is deleted from Table[#{table}]"
      end

      # It generates an xml document that represents instance of this class.
      # +one_session+ a string that represents OpenNebula user session.
      def to_xml_element(one_session)
        raise NotImplementedException
      end

      protected

      def table
        self.class.table_name
      end

      def raise_if_nil(obj, obj_name)
        unless obj
          raise "'#{obj_name}' must not be nil."
        end
      end

      def raise_if_nil_and_not_class(obj, obj_name, cls)
        unless obj
          raise "'#{obj_name}' must not be nil."
        end
        unless obj.kind_of?(cls)
          raise "'#{obj_name}' must be an #{cls.name}"
        end
      end

      def raise_if_nil_or_not_class(obj, obj_name, cls)
        unless obj == nil || obj.kind_of?(cls)
          raise "'#{obj_name}' must be nil or a #{cls.name}"
        end
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
        Database.execute(sql) do |row|  # TODO log
          return false if row[0] != '0'
        end

        Database.transaction(@table_schema)
        return true
      end

      # It finds and returns an array that contains records that match
      # the given +condition+.
      # It returns nil if not found.
      def self.find(condition)
        sql = "SELECT * FROM #{@table_name} WHERE #{condition}"
        result = []
        Database.execute(sql) do |val|
          result << gen_instance(val)
        end
        return result
      end

      # It finds and returns a record whose id is +id+.
      # It returns nil if not found.
      def self.find_by_id(id)
        find("id=#{id}")
      end

      # It finds and returns a record whose name is +name+.
      # It returns nil if not found.
      def self.find_by_name(name)
        find(to_find_by_name_cond_str(name))
      end

      # It finds and returns a record whose name or id is +arg+.
      # It returns nil if not found.
      def self.find_by_id_or_name(arg)
        if /^\d+$/ =~ arg
          find_by_id(arg)
        else
          find_by_name(arg)
        end
      end

      # It returns a string used in self.find_by_name.
      def self.to_find_by_name_cond_str(name)
        return @field_for_find_by_name + '=' + "'#{name}'"
      end

      # It iterates all records stored in db.
      def self.each
        sql = "SELECT * FROM #{@table_name}"
        Database.execute(sql) do |row|
          yield gen_instance(row)
        end
      end

      # It generates instance of this class using attr.
      # +attr+   array of values for instance fields
      # +return+ instance of this class
      def self.gen_instance(attrs)
        return setup_attrs(self.new, attrs)
      end

      # It sets fields(attrs) to an object(obj).
      # +obj+   an object where fields are set
      # +attrs+ array of field value
      def self.setup_attrs(obj, attrs)
        raise NotImplementedException
      end
    end

  end
end


# Local Variables:
# mode: Ruby
# coding: utf-8-unix
# indent-tabs-mode: nil
# End:
