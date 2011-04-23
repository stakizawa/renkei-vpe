require 'renkei-vpe-server/model/base'

module RenkeiVPE
  ############################################################################
  # A module whose classes store Renkei VPE data
  ############################################################################
  module Model
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
  leases      TEXT
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
      attr_accessor :leases       # ids of vm leases, splitted by ' '


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
          "leases='#{@leases}'"            +
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
        raise_if_nil_and_not_class(@leases,      'leases',      String)
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
          "'#{@leases}'"
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
          "leases='#{@leases}'"
      end


      def self.setup_attrs(vn, attrs)
        return vn unless attrs.size == 12
        vn.instance_eval do
          @id          = attrs[0].to_i
          @oid         = attrs[1].to_i
          @name        = attrs[2]
          @description = attrs[3]
          @zone_name   = attrs[4]
          @unique_name = attrs[5]
          @address     = attrs[6]
          @netmask     = attrs[7]
          @gateway     = attrs[8]
          @dns         = attrs[9]
          @ntp         = attrs[10]
          @leases      = attrs[11]
        end
        return vn
      end

    end
  end
end


# Local Variables:
# mode: Ruby
# coding: utf-8-unix
# indent-tabs-mode: nil
# End:
