#
# Copyright 2011-2013 Shinichiro Takizawa
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#


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

      # id of one network
      attr_accessor(:oid) { |v| v.to_i }
      # name of the network
      attr_accessor :name
      # description of the network
      attr_accessor :description
      # name of zone where the network belongs
      attr_accessor :zone_name
      # global unique name of the network
      attr_accessor :unique_name
      # network address
      attr_accessor :address
      # netmask of the network
      attr_accessor :netmask
      # gateway of the network
      attr_accessor :gateway
      # dns servers of the network, splitted by ' '
      attr_accessor :dns
      # ntp servers of the network, splitted by ' '
      attr_accessor :ntp
      # ids of leases, splitted by ' '
      attr_accessor :leases

      def initialize
        super
        @oid         = -1
        @name        = ''
        @description = ''
        @zone_name   = ''
        @unique_name = ''
        @address     = ''
        @netmask     = ''
        @gateway     = ''
        @dns         = ''
        @ntp         = ''
        @leases      = ''
      end

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

      def to_xml_element(one_session)
        # get one vnet
        rc = call_one_xmlrpc('one.vn.info', one_session, @oid)
        raise rc[1] unless rc[0]
        onevn_doc = REXML::Document.new(rc[1])

        # toplevel VNET element
        vnet_e = REXML::Element.new('VNET')

        # set id
        id_e = REXML::Element.new('ID')
        id_e.add(REXML::Text.new(@id.to_s))
        vnet_e.add(id_e)

        # set name
        name_e = REXML::Element.new('NAME')
        name_e.add(REXML::Text.new(@name))
        vnet_e.add(name_e)

        # set zone name
        name_e = REXML::Element.new('ZONE')
        name_e.add(REXML::Text.new(@zone_name))
        vnet_e.add(name_e)

        # set unique name
        name_e = REXML::Element.new('UNIQUE_NAME')
        name_e.add(REXML::Text.new(@unique_name))
        vnet_e.add(name_e)

        # set description
        desc_e = REXML::Element.new('DESCRIPTION')
        desc_e.add(REXML::Text.new(@description))
        vnet_e.add(desc_e)

        # set network address
        addr_e = REXML::Element.new('ADDRESS')
        addr_e.add(REXML::Text.new(@address))
        vnet_e.add(addr_e)

        # set netmask
        mask_e = REXML::Element.new('NETMASK')
        mask_e.add(REXML::Text.new(@netmask))
        vnet_e.add(mask_e)

        # set gateway
        gw_e = REXML::Element.new('GATEWAY')
        gw_e.add(REXML::Text.new(@gateway))
        vnet_e.add(gw_e)

        # set dns servers
        dns_e = REXML::Element.new('DNS')
        dns_e.add(REXML::Text.new(@dns))
        vnet_e.add(dns_e)

        # set ntp servers
        ntp_e = REXML::Element.new('NTP')
        ntp_e.add(REXML::Text.new(@ntp))
        vnet_e.add(ntp_e)

        # set physical host side interface
        if_e = REXML::Element.new('HOST_INTERFACE')
        if_e.add(onevn_doc.get_text('VNET/BRIDGE'))
        vnet_e.add(if_e)


        # set virtual host leases
        leases_e = REXML::Element.new('LEASES')
        vnet_e.add(leases_e)
        @leases.strip.split(/\s+/).map{ |i| i.to_i }.each do |hid|
          l = Lease.find_by_id(hid)[0]
          raise not_found_msg unless l
          leases_e.add(l.to_xml_element(one_session))
        end

        return vnet_e
      end

      # It returns an array containing lease ids in integer.
      def leases_in_array
        @leases.strip.split(/\s+/).map { |i| i.to_i }
      end

      # It returns available lases in this virtual network.
      # +assigned_user+  id of user who owns lease
      def find_available_leases(assigned_user=-1)
        res = Lease.find("vnetid=#{@id} AND used=0 AND assigned_to=-1")
        if res.empty? && assigned_user != -1
          res = Lease.find("vnetid=#{@id} AND used=0 AND assigned_to=#{assigned_user}")
        end
        return res
      end

      # It adds a lease.
      # +l_id+  id of lease to be added.
      def add_lease(l_id)
        @leases = (@leases || '') + "#{l_id} "
      end

      # It removes a lease.
      # +l_id+  id of lease to be removed.
      def remove_lease(l_id)
        leases = leases_in_array
        leases.delete(l_id)
        @leases = leases.join(' ') + ' '
      end

      # It returns true, if the specified id lease is included in this vnet.
      # +l_id+  id of lease to be checked.
      def include_lease?(l_id)
        leases = leases_in_array
        leases.include?(l_id)
      end

      # It adds a type-ed server
      def add_server(type, server)
        servers_s = self.send(type)
        servers_a = servers_s.strip.split(/\s+/)

        unless servers_a.include? server
          servers_a << server
          servers_s = servers_a.join(' ')
          self.send("#{type}=".to_sym, servers_s)
        end
      end

      # It removes a type-ed server
      def remove_server(type, server)
        servers_s = self.send(type)
        servers_a = servers_s.strip.split(/\s+/)

        if servers_a.include? server
          servers_a.delete(server)
          servers_s = servers_a.join(' ')
          self.send("#{type}=".to_sym, servers_s)
        end
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
        end
        vn.oid         = attrs[1]
        vn.name        = attrs[2]
        vn.description = attrs[3]
        vn.zone_name   = attrs[4]
        vn.unique_name = attrs[5]
        vn.address     = attrs[6]
        vn.netmask     = attrs[7]
        vn.gateway     = attrs[8]
        vn.dns         = attrs[9]
        vn.ntp         = attrs[10]
        vn.leases      = attrs[11]
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
