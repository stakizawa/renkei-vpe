require 'renkei-vpe-server/model/base'

module RenkeiVPE
  ############################################################################
  # A module whose classes store Renkei VPE data
  ############################################################################
  module Model
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

      # id of the accosiated one cluster
      attr_accessor(:oid) { |v| v.to_i }
      # name of the zone
      attr_accessor :name
      # description of the zone
      attr_accessor :description
      # hosts that host VMs and belong to the zone
      attr_accessor :hosts
      # networks belong to the zone
      attr_accessor :networks

      def initialize
        super
        @oid         = -1
        @name        = ''
        @description = ''
        @hosts       = ''
        @networks    = ''
      end

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


      def self.setup_attrs(z, attrs)
        return z unless attrs.size == 6
        z.instance_eval do
          @id          = attrs[0].to_i
        end
        z.oid         = attrs[1]
        z.name        = attrs[2]
        z.description = attrs[3]
        z.hosts       = attrs[4]
        z.networks    = attrs[5]
        return z
      end

    end
  end
end


# Local Variables:
# mode: Ruby
# coding: utf-8-unix
# indent-tabs-mode: nil
# End:
