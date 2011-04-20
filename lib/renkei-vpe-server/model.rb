require 'renkei-vpe-server/logger'
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
      Model::VirtualNetwork.create_table_if_necessary
      Model::VirtualHost.create_table_if_necessary
      Model::VMType.create_table_if_necessary
      Model::VirtualMachine.create_table_if_necessary
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

      # table field name used in self.find_by_name
      @field_for_find_by_name = nil

      # id of instance of this model
      attr_reader :id

      def initialize(*args)
        @log = RenkeiVPE::Logger.get_logger
      end

      # creates a record that represents this instance on the table.
      def create
        check_fields
        sql = "INSERT INTO #{table} VALUES (NULL,#{to_create_record_str})"
        Database.transaction(sql)
        sql = "SELECT id FROM #{table} WHERE #{to_find_id_str}"
        @id = Database.execute(sql)[0]
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
        Database.execute(sql) do |row|
          return false if row[0] != '0'
        end

        Database.transaction(@table_schema)
        return true
      end

      # It finds and returns records that match the given +condition+.
      # It returns nil if not found.
      def self.find(condition)
        sql = "SELECT * FROM #{@table_name} WHERE #{condition};"
        vals = Database.execute(sql)
        return nil unless vals
        return gen_instance(vals)
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
      def self.gen_instance(attr)
        raise NotImplementedException
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
  oid     INTEGER UNIQUE,
  name    VARCHAR(256) UNIQUE,
  enabled INTEGER,
  zones   TEXT
);
SQL

      @field_for_find_by_name = 'name'

      attr_accessor :oid      # id of the accosiated one user
      attr_accessor :name     # name of the user
      attr_accessor :enabled  # a flag is the user is enabled(1) or not(0)
      attr_accessor :zones    # names of zones the user can use

      def to_s
        "User<"                  +
          "id=#{@id},"           +
          "oid=#{@oid},"         +
          "name='#{@name}',"     +
          "enabled=#{@enabled}," +
          "zones='#{@zones}'"    +
          ">"
      end

      protected

      def check_fields
        raise_if_nil_and_not_class(@oid,     'oid',     Integer)
        raise_if_nil_and_not_class(@name,    'name',    String)
        raise_if_nil_and_not_class(@enabled, 'enabled', Integer)
        raise_if_nil_or_not_class( @zones,   'zones',   String)
      end

      def to_create_record_str
        "#{@oid},"       +
          "'#{@name}',"  +
          "#{@enabled}," +
          "'#{@zones}'"
      end

      def to_find_id_str
        "name='#{@name}'"
      end

      def to_update_record_str
        "oid=#{@oid},"           +
          "name='#{@name}',"     +
          "enabled=#{@enabled}," +
          "zones='#{@zones}'"
      end


      def self.gen_instance(attr)
        u = User.new
        u.instance_eval do
          @id      = attr[0].to_i
          @oid     = attr[1].to_i
          @name    = attr[2]
          @enabled = attr[3].to_i
          @zones   = attr[4]
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
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  oid         INTEGER UNIQUE,
  name        VARCHAR(256) UNIQUE,
  description TEXT,
  hosts       TEXT,
  networks    TEXT
);
SQL

      @field_for_find_by_name = 'name'

      attr_accessor :oid         # id of the accosiated one cluster
      attr_accessor :name        # name of the zone
      attr_accessor :description # description of the zone
      attr_accessor :hosts       # hosts that host VMs and belong to the zone
      attr_accessor :networks    # networks belong to the zone

      def to_s
        "Zone<"                            +
          "id=#{@id},"                     +
          "oid=#{@oid},"                   +
          "name='#{@name}',"               +
          "description='#{@description}'," +
          "hosts='#{@hosts}',"             +
          "networks='#{@networks}'"        +
          ">"
      end

      protected

      def check_fields
        raise_if_nil_and_not_class(@oid,         'oid',         Integer)
        raise_if_nil_and_not_class(@name,        'name',        String)
        raise_if_nil_or_not_class( @description, 'description', String)
        raise_if_nil_or_not_class( @hosts,       'hosts',       String)
        raise_if_nil_or_not_class( @networks,    'networks',    String)
      end

      def to_create_record_str
        "#{@oid},"             +
          "'#{@name}',"        +
          "'#{@description}'," +
          "'#{@hosts}',"       +
          "'#{@networks}'"
      end

      def to_find_id_str
        "name='#{@name}'"
      end

      def to_update_record_str
        "oid=#{@oid},"                     +
          "name='#{@name}',"               +
          "description='#{@description}'," +
          "hosts='#{@hosts}',"             +
          "networks='#{@networks}'"
      end


      def self.gen_instance(attr)
        z = Zone.new
        z.instance_eval do
          @id          = attr[0].to_i
          @oid         = attr[1].to_i
          @name        = attr[2]
          @description = attr[3]
          @hosts       = attr[4]
          @networks    = attr[5]
        end
        return z
      end

    end

    ##########################################################################
    # Model for Virtual Network
    ##########################################################################
    class VirtualNetwork < BaseModel
      @table_name = 'virtual_networks'

      @table_schema = <<SQL
CREATE TABLE #{@table_name} (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  oid         INTEGER UNIQUE,
  name        VARCHAR(256),
  description TEXT,
  zone_name   VARCHAR(256),
  unique_name VARCHAR(256) UNIQUE,
  address     VARCHAR(256),
  netmask     VARCHAR(256),
  gateway     VARCHAR(256),
  dns         TEXT,
  ntp         TEXT,
  vhosts      TEXT
);
SQL

      @field_for_find_by_name = 'unique_name'

      attr_accessor :oid          # id of one network
      attr_accessor :name         # name of the network
      attr_accessor :description  # description of the network
      attr_accessor :zone_name    # name of zone where the network belongs
      attr_accessor :unique_name  # global unique name of the network
      attr_accessor :address      # network address
      attr_accessor :netmask      # netmask of the network
      attr_accessor :gateway      # gateway of the network
      attr_accessor :dns          # dns servers of the network, splitted by ' '
      attr_accessor :ntp          # ntp servers of the network, splitted by ' '
      attr_accessor :vhosts       # ids of virtual hosts, splitted by ' '


      def to_s
        "VirtualNetwork<"                  +
          "id=#{@id},"                     +
          "oid=#{@oid},"                   +
          "name='#{@name}',"               +
          "description='#{@description}'," +
          "zone_name='#{@zone_name}',"     +
          "unique_name='#{@unique_name}'," +
          "address='#{@address}',"         +
          "netmask='#{@netmask}',"         +
          "gateway='#{@gateway}',"         +
          "dns='#{@dns}',"                 +
          "ntp='#{@ntp}',"                 +
          "vhosts='#{@vhosts}'"            +
          ">"
      end

      protected

      def check_fields
        raise_if_nil_and_not_class(@oid,         'oid',         Integer)
        raise_if_nil_and_not_class(@name,        'name',        String)
        raise_if_nil_or_not_class( @description, 'description', String)
        raise_if_nil_and_not_class(@zone_name,   'zone_name',   String)
        raise_if_nil_and_not_class(@unique_name, 'unique_name', String)
        raise_if_nil_and_not_class(@address,     'address',     String)
        raise_if_nil_and_not_class(@netmask,     'netmask',     String)
        raise_if_nil_and_not_class(@gateway,     'gateway',     String)
        raise_if_nil_and_not_class(@dns,         'dns',         String)
        raise_if_nil_and_not_class(@ntp,         'ntp',         String)
        raise_if_nil_and_not_class(@vhosts,      'vhosts',      String)
      end

      def to_create_record_str
        "#{@oid},"             +
          "'#{@name}',"        +
          "'#{@description}'," +
          "'#{@zone_name}',"   +
          "'#{@unique_name}'," +
          "'#{@address}',"     +
          "'#{@netmask}',"     +
          "'#{@gateway}',"     +
          "'#{@dns}',"         +
          "'#{@ntp}',"         +
          "'#{@vhosts}'"
      end

      def to_find_id_str
        "unique_name='#{@unique_name}'"
      end

      def to_update_record_str
        "oid=#{@oid},"                     +
          "name='#{@name}',"               +
          "description='#{@description}'," +
          "zone_name='#{@zone_name}',"     +
          "unique_name='#{@unique_name}'," +
          "address='#{@address}',"         +
          "netmask='#{@netmask}',"         +
          "gateway='#{@gateway}',"         +
          "dns='#{@dns}',"                 +
          "ntp='#{@ntp}',"                 +
          "vhosts='#{@vhosts}'"
      end


      def self.gen_instance(attr)
        vn = VirtualNetwork.new
        vn.instance_eval do
          @id          = attr[0].to_i
          @oid         = attr[1].to_i
          @name        = attr[2]
          @description = attr[3]
          @zone_name   = attr[4]
          @unique_name = attr[5]
          @address     = attr[6]
          @netmask     = attr[7]
          @gateway     = attr[8]
          @dns         = attr[9]
          @ntp         = attr[10]
          @vhosts      = attr[11]
        end
        return vn
      end

    end

    ##########################################################################
    # Model for Virtual Host that belongs to a specific Virtual Network
    ##########################################################################
    class VirtualHost < BaseModel  # TODO rename to VMLease
      @table_name = 'virtual_hosts'

      @table_schema = <<SQL
CREATE TABLE #{@table_name} (
  id        INTEGER PRIMARY KEY AUTOINCREMENT,
  name      VARCHAR(256),
  address   VARCHAR(256),
  allocated INTEGER,
  vnetid    INTEGER
);
SQL

      @field_for_find_by_name = 'name'

      attr_accessor :name      # name of the vhost must be an FQDN
      attr_accessor :address   # IP address of the vhost
      attr_accessor :allocated # 1 when it is allocated, othersize 0
      attr_accessor :vnetid    # id of the vnet the vhost belongs to

      def to_s
        "VirtualHost<"               +
          "id=#{@id},"               +
          "name='#{@name}',"         +
          "address='#{@address}',"   +
          "allocated=#{@allocated}," +
          "vnetid=#{@vnetid}"        +
          ">"
      end

      protected

      def check_fields
        raise_if_nil_and_not_class(@name,      'name',      String)
        raise_if_nil_and_not_class(@address,   'address',   String)
        raise_if_nil_and_not_class(@allocated, 'allocated', Integer)
        raise_if_nil_and_not_class(@vnetid,    'vnetid',    Integer)
      end

      def to_create_record_str
        "'#{@name}',"      +
          "'#{@address}'," +
          "#{@allocated}," +
          "#{@vnetid}"
      end

      def to_find_id_str
        "name='#{@name}'"
      end

      def to_update_record_str
        "name='#{@name}',"           +
          "address='#{@address}',"   +
          "allocated=#{@allocated}," +
          "vnetid=#{@vnetid}"
      end


      def self.gen_instance(attr)
        vh = VirtualHost.new
        vh.instance_eval do
          @id        = attr[0].to_i
          @name      = attr[1]
          @address   = attr[2]
          @allocated = attr[3].to_i
          @vnetid    = attr[4].to_i
        end
        return vh
      end

    end

    ##########################################################################
    # Model for Virtual Machine type
    ##########################################################################
    class VMType < BaseModel
      @table_name = 'vm_types'

      @table_schema = <<SQL
CREATE TABLE #{@table_name} (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  name        VARCHAR(256),
  cpu         INTEGER,
  memory      INTEGER,
  description TEXT
);
SQL

      @field_for_find_by_name = 'name'

      attr_accessor :name        # name of the VM type
      attr_accessor :cpu         # number of cpus
      attr_accessor :memory      # amount of memory in MB
      attr_accessor :description # description of the VM type

      def to_s
        "VMType<"                         +
          "id=#{@id},"                    +
          "name='#{@name}',"              +
          "cpu=#{@cpu},"                  +
          "memory=#{@memory}"             +
          "description='#{@description}'" +
          ">"
      end

      protected

      def check_fields
        raise_if_nil_and_not_class(@name,        'name',        String)
        raise_if_nil_and_not_class(@cpu,         'cpu',         Integer)
        raise_if_nil_and_not_class(@memory,      'memory',      Integer)
        raise_if_nil_or_not_class( @description, 'description', String)
      end

      def to_create_record_str
        "'#{@name}',"  +
          "#{@cpu},"   +
          "#{@memory}," +
          "'#{@description}'"
      end

      def to_find_id_str
        "name='#{@name}'"
      end

      def to_update_record_str
        "name='#{@name}',"    +
          "cpu=#{@cpu},"      +
          "memory=#{@memory}," +
          "description='#{@description}'"
      end


      def self.gen_instance(attr)
        type = VMType.new
        type.instance_eval do
          @id          = attr[0].to_i
          @name        = attr[1]
          @cpu         = attr[2].to_i
          @memory      = attr[3].to_i
          @description = attr[4]
        end
        return type
      end

    end

    ##########################################################################
    # Model for Virtual Machine
    ##########################################################################
    class VirtualMachine < BaseModel
      @table_name = 'virtual_machines'

      @table_schema = <<SQL
CREATE TABLE #{@table_name} (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  oid         INTEGER UNIQUE,
  user_id     INTEGER,
  zone_id     INTEGER,
  lease_id    INTEGER,
  type_id     INTEGER,
  image_id    INTEGER
);
SQL

      @field_for_find_by_name = 'name'

      attr_accessor :oid        # id of one VM
      attr_accessor :user_id    # id of the VM user
      attr_accessor :zone_id    # id of a zone the VM is located
      attr_accessor :lease_id   # id of virtual machine lease
      attr_accessor :type_id    # id of the VM type
      attr_accessor :image_id   # id of OS image the VM use

      def initialize(*args)
        super

        self.class.setup_attrs(self, args) # TODO move to super class
      end

      def to_s
        "VirtualMachine<"          +
          "id=#{@id},"             +
          "oid=#{@oid},"           +
          "user_id=#{@user_id},"   +
          "zone_id=#{@zone_id},"   +
          "lease_id=#{@lease_id}," +
          "type_id=#{@type_id},"   +
          "image_id=#{@image_id}," +
          ">"
      end

      protected

      def check_fields
        raise_if_nil_and_not_class(@oid,      'oid',      Integer)
        raise_if_nil_and_not_class(@user_id,  'user_id',  Integer)
        raise_if_nil_and_not_class(@zone_id,  'zone_id',  Integer)
        raise_if_nil_and_not_class(@lease_id, 'lease_id', Integer)
        raise_if_nil_and_not_class(@type_id,  'type_id',  Integer)
        raise_if_nil_and_not_class(@image_id, 'image_id', Integer)
      end

      def to_create_record_str
        "#{@oid},"        +
          "#{@user_id},"  +
          "#{@zone_id},"  +
          "#{@lease_id}," +
          "#{@type_id},"  +
          "#{@image_id}"
      end

      def to_find_id_str
        "oid=#{@oid}"
      end

      def to_update_record_str
        "oid=#{@oid},"             +
          "user_id=#{@user_id},"   +
          "zone_id=#{@zone_id},"   +
          "lease_id=#{@lease_id}," +
          "type_id=#{@type_id},"   +
          "image_id=#{@image_id}"
      end


      # TODO also implement in other class
      def self.setup_attrs(vm, attrs)
        vm.instance_eval do
          @id       = attrs[0].to_i
          @oid      = attrs[1].to_i
          @user_id  = attrs[2].to_i
          @zone_id  = attrs[3].to_i
          @lease_id = attrs[4].to_i
          @type_id  = attrs[5].to_i
          @image_id = attrs[6].to_i
        end
        return vm
      end

      # TODO move to BaseModel
      def self.gen_instance(attrs)
        return setup_attrs(self.new, attrs)
      end

    end

  end
end


### test
if __FILE__ == $0
  require 'pp'
  require 'fileutils'
  require 'test/unit'

  RenkeiVPE::Logger.init('rvped.log')

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
