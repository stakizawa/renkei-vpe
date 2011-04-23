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

      def to_xml_element(one_session)
        # toplevel ZONE element
        zone_e = REXML::Element.new('ZONE')

        # set id
        id_e = REXML::Element.new('ID')
        id_e.add(REXML::Text.new(@id.to_s))
        zone_e.add(id_e)

        # set name
        name_e = REXML::Element.new('NAME')
        name_e.add(REXML::Text.new(@name))
        zone_e.add(name_e)

        # set hosts
        hosts_e = REXML::Element.new('HOSTS')
        zone_e.add(hosts_e)
        @hosts.strip.split(/\s+/).map{ |i| i.to_i }.each do |hid|
          rc = call_one_xmlrpc('one.host.info', one_session, hid)
          raise rc[1] unless rc[0]

          hid_e = REXML::Element.new('ID')
          hid_e.add(REXML::Document.new(rc[1]).get_text('HOST/ID'))
          hname_e = REXML::Element.new('NAME')
          hname_e.add(REXML::Document.new(rc[1]).get_text('HOST/NAME'))
          host_e = REXML::Element.new('HOST')
          host_e.add(hid_e)
          host_e.add(hname_e)
          hosts_e.add(host_e)
        end

        # set networks
        nets_e = REXML::Element.new('NETWORKS')
        zone_e.add(nets_e)
        @networks.strip.split(/\s+/).map{ |i| i.to_i }.each do |nid|
          vnet = VirtualNetwork.find_by_id(nid)[0]
          raise "VirtualNetwork[#{nid}] is not found." unless vnet

          nid_e = REXML::Element.new('ID')
          nid_e.add(REXML::Text.new(nid.to_s))
          nname_e = REXML::Element.new('NAME')
          nname_e.add(REXML::Text.new(vnet.name))
          net_e = REXML::Element.new('NETWORK')
          net_e.add(nid_e)
          net_e.add(nname_e)
          nets_e.add(net_e)
        end

        return zone_e
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
