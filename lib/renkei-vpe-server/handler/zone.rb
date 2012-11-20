#
# Copyright 2011-2012 Shinichiro Takizawa
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


require 'renkei-vpe-server/handler/base'
require 'renkei-vpe-server/resource_file'
require 'fileutils'
require 'rexml/document'

module RenkeiVPE
  module Handler

    class ZoneHandler < BaseHandler
      ########################################################################
      # Define xml rpc interfaces
      ########################################################################
      INTERFACE = XMLRPC::interface('rvpe.zone') do
        meth('val pool(string)',
             'Retrieve information about zone group',
             'pool')
        meth('val ask_id(string, string)',
             'Retrieve id of the given-named zone',
             'ask_id')
        meth('val info(string, int)',
             'Retrieve information about the zone',
             'info')
        meth('val allocate(string, string)',
             'Allocates a new zone',
             'allocate')
        meth('val delete(string, int)',
             'Deletes a zone from the zone pool',
             'delete')
        meth('val add_host(string, int, string)',
             'add a new host to the zone',
             'add_host')
        meth('val remove_host(string, int, string)',
             'remove a host from the zone',
             'remove_host')
        meth('val add_vnet(string, int, string)',
             'add a new virtual network to the zone',
             'add_vnet')
        meth('val remove_vnet(string, int, string)',
             'remove a virtual network from the zone',
             'remove_vnet')
        meth('val sync(string)',
             'synchronize probes with remote hosts in all zones',
             'sync')
      end


      ########################################################################
      # Implement xml rpc functions
      ########################################################################

      # return information about user group.
      # +session+   string that represents user session
      # +return[0]+ true or false whenever is successful or not
      # +return[1]+ if an error occurs this is error message,
      #             if successful this is the information string
      def pool(session)
        read_task('rvpe.zone.pool', session) do
          doc = REXML::Document.new
          pool_e = REXML::Element.new('ZONE_POOL')
          doc.add(pool_e)

          Zone.each do |z|
            zone_e = z.to_xml_element(session)
            pool_e.add(zone_e)
          end

          return [true, doc.to_s]
        end
      end

      # return id of the given-named zone.
      # +session+   string that represents user session
      # +name+      name of a zone
      # +return[0]+ true or false whenever is successful or not
      # +return[1]+ if an error occurs this is error message,
      #             if successful this is the id of the zone.
      def ask_id(session, name)
        read_task('rvpe.zone.ask_id', session) do
          z = Zone.find_by_name(name).last
          raise "Zone[#{name}] is not found. " unless z

          [true, z.id]
        end
      end

      # return information about this zone.
      # +session+   string that represents user session
      # +id+        id of the zone
      # +return[0]+ true or false whenever is successful or not
      # +return[1]+ if an error occurs this is error message,
      #             if successful this is the string with the information
      #             about the zone
      def info(session, id)
        read_task('rvpe.zone.info', session) do
          zone = Zone.find_by_id(id)[0]
          raise "Zone[#{id}] is not found." unless zone

          zone_e = zone.to_xml_element(session)
          doc = REXML::Document.new
          doc.add(zone_e)

          [true, doc.to_s]
        end
      end

      # allocates a new zone.
      # +session+   string that represents user session
      # +template+  a string containing the template of the zone
      # +return[0]+ true or false whenever is successful or not
      # +return[1]+ if an error occurs this is the error message,
      #             if successful this is the associated id (int id)
      #             generated for this zone
      def allocate(session, template)
        write_task('rvpe.zone.allocate', session, true) do
          zone_def = ResourceFile::Parser.load_yaml(template)

          # create a zone
          name = zone_def[ResourceFile::Zone::NAME]
          unless name
            raise 'Specify ' + ResourceFile::Zone::NAME + ' in Zone file.'
          end
          zone = Zone.find_by_name(name).last
          raise "Zone[#{name}] already exists." if zone
          # create an associated site in OpenNebula
          rc = call_one_xmlrpc('one.cluster.allocate', session, name)
          raise rc[1] unless rc[0]
          osite_id = rc[1]
          # create a zone record
          begin
            zone = Zone.new
            zone.oid = osite_id
            zone.name = name
            zone.description = zone_def[ResourceFile::Zone::DESCRIPTION]
            zone.create
          rescue => e
            call_one_xmlrpc('one.cluster.delete', session, osite_id)
            raise e
          end

          # add hosts to this zone
          if zone_def[ResourceFile::Zone::HOST]
            begin
              zone_def[ResourceFile::Zone::HOST].each do |host|
                add_host_to_zone(session, host, zone)
              end
            rescue => e
              # delete this zone
              _delete(session, zone)
              raise e
            end
          end

          # add virtual networks to this zone
          if zone_def[ResourceFile::Zone::NETWORK]
            begin
              zone_def[ResourceFile::Zone::NETWORK].each do |net|
                add_vnet_to_zone(session, net, zone)
              end
            rescue => e
              # delete this zone
              _delete(session, zone)
              raise e
            end
          end

          [true, zone.id]
        end
      end

      # deletes a zone from the zone pool.
      # +session+   string that represents user session
      # +id+        id of the zone
      # +return[0]+ true or false whenever is successful or not
      # +return[1]+ if an error occurs this is error message,
      #             otherwise it does not exist.
      def delete(session, id)
        write_task('rvpe.zone.delete', session, true) do
          zone = Zone.find_by_id(id)[0]
          raise "Zone[#{id}] does not exist." unless zone

          _delete(session, zone)
        end
      end

      # add a new host to the zone.
      # +session+   string that represents user session
      # +id+        id of the zone
      # +host_name+ name of host added to the zone
      # +return[0]+ true or false whenever is successful or not
      # +return[1]+ if an error occurs this is error message,
      #             otherwise it does not exist.
      def add_host(session, id, host_name)
        write_task('rvpe.zone.add_host', session, true) do
          zone = Zone.find_by_id(id)[0]
          raise "Zone[#{id}] does not exist." unless zone

          add_host_to_zone(session, host_name, zone)
          [true, '']
        end
      end

      # remove a host from the zone.
      # +session+   string that represents user session
      # +id+        id of the zone
      # +host_name+ name of host removed from the zone
      # +return[0]+ true or false whenever is successful or not
      # +return[1]+ if an error occurs this is error message,
      #             otherwise it does not exist.
      def remove_host(session, id, host_name)
        write_task('rvpe.zone.remove_host', session, true) do
          zone = Zone.find_by_id(id)[0]
          raise "Zone[#{id}] does not exist." unless zone

          remove_host_from_zone(session, host_name, zone)
          [true, '']
        end
      end

      # add a new virtual network to the zone.
      # +session+   string that represents user session
      # +id+        id of the zone
      # +template+  a string containing the template of the virtual network
      # +return[0]+ true or false whenever is successful or not
      # +return[1]+ if an error occurs this is error message,
      #             otherwise it does not exist.
      def add_vnet(session, id, template)
        write_task('rvpe.zone.add_vnet', session, true) do
          zone = Zone.find_by_id(id)[0]
          raise "Zone[#{id}] does not exist." unless zone

          vnet_def = ResourceFile::Parser.load_yaml(template)
          add_vnet_to_zone(session, vnet_def, zone)
          [true, '']
        end
      end

      # remove a virtual network from the zone.
      # +session+   string that represents user session
      # +id+        id of the zone
      # +vnet_name+ name of virtual network removed from the zone
      # +return[0]+ true or false whenever is successful or not
      # +return[1]+ if an error occurs this is error message,
      #             otherwise it does not exist.
      def remove_vnet(session, id, vnet_name)
        write_task('rvpe.zone.remove_vnet', session, true) do
          zone = Zone.find_by_id(id)[0]
          raise "Zone[#{id}] does not exist." unless zone

          remove_vnet_from_zone(session, vnet_name, zone)
          [true, '']
        end
      end

      # synchronize probes with remote hosts in all zones.
      # +session+   string that represents user session
      # +return[0]+ always true
      # +return[1]+ always ''
      def sync(session)
        write_task('rvpe.zone.sync', session, true) do
          one_loc = $server_config.one_location
          if one_loc
            FileUtils.touch "#{one_loc}/var/remotes"
          else
            FileUtils.touch '/var/lib/one/remotes'
          end
          [true, '']
        end
      end


      private

      def _delete(session, zone)
        err_msg = ''

        # delete virtual networks
        zone.networks_in_array.each do |nid|
          begin
            remove_vnet_from_zone(session, nid, zone)
          rescue => e
            err_msg = (err_msg.size == 0)? e.message : err_msg +'; '+ e.message
          end
        end

        # delete hosts
        zone.hosts_in_array.each do |hid|
          begin
            remove_host_from_zone(session, hid, zone)
          rescue => e
            err_msg = (err_msg.size == 0)? e.message : err_msg +'; '+ e.message
          end
        end

        # delete the associated site from OpenNebula
        rc = call_one_xmlrpc('one.cluster.delete', session, zone.oid)
        unless rc[0]
          err_msg = (err_msg.size == 0)? rc[1] : err_msg + '; ' + rc[1]
        end

        # delete zone from user records
        User.each(session) do |user|
          user.modify_zone(zone.id, false, -1)
          user.update
        end

        # delete zone record
        begin
          zone.delete
        rescue => e
          err_msg = (err_msg.size == 0)? e.message : err_msg + '; ' + e.message
        end

        result = (err_msg.size == 0)? true : false
        [result, err_msg]
      end

      # +session+   string that represents user session
      # +host_name+ name of host
      # +zone+      instance of a zone
      # +return+    id of host
      def add_host_to_zone(session, host_name, zone)
        # allocate host (only in OpenNebula)
        rc = call_one_xmlrpc('one.host.allocate', session,
                             host_name, 'im_kvm', 'vmm_rvpe', 'tm_gfarm')
        raise rc[1] unless rc[0]

        # add the host to a site in OpenNebula
        hid = rc[1]
        rc = call_one_xmlrpc('one.cluster.add', session, hid, zone.oid)
        unless rc[0]
          # delete host
          call_one_xmlrpc('one.host.delete', session, hid)
          raise rc[1]
        end

        # add host to the zone
        begin
          zone.add_host(hid)
          zone.update
        rescue => e
          # remove host from site
          call_one_xmlrpc('one.cluster.remove', session, hid)
          # delete host
          call_one_xmlrpc('one.host.delete', session, hid)
          raise e
        end

        return hid
      end

      # +session+ string that represents user session
      # +host+    name or instance of host
      # +zone+    instance of a zone
      # +return+  id of removed host
      def remove_host_from_zone(session, host, zone)
        host_id = host
        if host.kind_of?(String)
          if host.match(/^[0123456789]+$/)
            host_id = host.to_i
          else
            # host is name of host
            zone.hosts_in_array.each do |hid|
              rc = call_one_xmlrpc('one.host.info', session, hid)
              doc = REXML::Document.new(rc[1])
              if host == doc.get_text('HOST/NAME').value
                host_id = doc.get_text('HOST/ID').value.to_i
                break
              end
            end
          end

          if host_id.kind_of?(String)
            raise "Host[#{host_id}] is not in Zone[#{zone.name}]."
          end
        end

        err_msg = ''

        # remove host from the zone
        begin
          old_hosts = zone.hosts_in_array
          zone.remove_host(host_id)
          new_hosts = zone.hosts_in_array
          unless old_hosts.size > new_hosts.size
            raise "Host[#{host_id}] is not in Zone[#{zone.name}]."
          end
          zone.update
        rescue => e
          err_msg = (err_msg.size == 0)? e.message : err_msg + '; ' + e.message
        end

        # remove the host from a site in OpenNebula
        rc = call_one_xmlrpc('one.cluster.remove', session, host_id)
        unless rc[0]
          err_msg = (err_msg.size == 0)? rc[1] : err_msg + '; ' + rc[1]
        end

        # delete the host (only from OpenNebula)
        rc = call_one_xmlrpc('one.host.delete', session, host_id)
        unless rc[0]
          err_msg = (err_msg.size == 0)? rc[1] : err_msg + '; ' + rc[1]
        end

        raise err_msg unless err_msg.size == 0
        return host_id
      end

      # +session+   string that represents user session
      # +vnet_def+  yaml object of vnet definition
      # +zone+      instance of a zone
      # +return+    id of vnet
      def add_vnet_to_zone(session, vnet_def, zone)
        name = vnet_def[ResourceFile::VirtualNetwork::NAME]
        unless name
          raise "Specify #{ResourceFile::VirtualNetwork::NAME} of the network."
        end
        vn_unique = zone.name + ATTR_SEPARATOR + name

        # 0. check fields
        # check network existence
        vnet = VirtualNetwork.find_by_name(vn_unique).last
        raise "VirtualNetwork[#{vn_unique}] already exists." if vnet
        # check bridge interface
        unless vnet_def[ResourceFile::VirtualNetwork::INTERFACE]
          raise "Specify #{ResourceFile::VirtualNetwork::INTERFACE} of the network."
        end
        # check network address
        unless vnet_def[ResourceFile::VirtualNetwork::ADDRESS]
          raise "Specify #{ResourceFile::VirtualNetwork::ADDRESS} of the network."
        end
        VNetHandler.check_ip_validity(vnet_def[ResourceFile::VirtualNetwork::ADDRESS])
        # check netmask
        unless vnet_def[ResourceFile::VirtualNetwork::NETMASK]
          raise "Specify #{ResourceFile::VirtualNetwork::NETMASK} of the network."
        end
        VNetHandler.check_ip_validity(vnet_def[ResourceFile::VirtualNetwork::NETMASK])
        # check gateway
        unless vnet_def[ResourceFile::VirtualNetwork::GATEWAY]
          raise "Specify #{ResourceFile::VirtualNetwork::GATEWAY} of the network."
        end
        VNetHandler.check_ip_validity(vnet_def[ResourceFile::VirtualNetwork::GATEWAY])
        # check dns servers
        unless vnet_def[ResourceFile::VirtualNetwork::DNS]
          raise "Specify #{ResourceFile::VirtualNetwork::DNS} of the network."
        end
        # check ntp servers
        unless vnet_def[ResourceFile::VirtualNetwork::NTP]
          raise "Specify #{ResourceFile::VirtualNetwork::NTP} of the network."
        end

        # 1. allocate vn in OpenNebula
        # create one vnet template
        one_vn_template = <<VN_DEF
NAME   = "#{vn_unique}"
TYPE   = FIXED
PUBLIC = YES

BRIDGE = #{vnet_def[ResourceFile::VirtualNetwork::INTERFACE]}
VN_DEF
        vnet_def[ResourceFile::VirtualNetwork::LEASE].each do |vh|
          one_vn_template +=
            "LEASES = [IP=\"#{vh[ResourceFile::VirtualNetwork::LEASE_ADDRESS]}\"]\n"
        end
        # call rpc
        rc = call_one_xmlrpc('one.vn.allocate', session, one_vn_template)
        raise rc[1] unless rc[0]

        # 2. create a vnet
        begin
          vn = VirtualNetwork.new
          vn.oid         = rc[1]
          vn.name        = name
          vn.description = vnet_def[ResourceFile::VirtualNetwork::DESCRIPTION]
          vn.zone_name   = zone.name
          vn.unique_name = vn_unique
          vn.address     = vnet_def[ResourceFile::VirtualNetwork::ADDRESS]
          vn.netmask     = vnet_def[ResourceFile::VirtualNetwork::NETMASK]
          vn.gateway     = vnet_def[ResourceFile::VirtualNetwork::GATEWAY]
          vn.dns         = vnet_def[ResourceFile::VirtualNetwork::DNS].join(' ')
          vn.ntp         = vnet_def[ResourceFile::VirtualNetwork::NTP].join(' ')
          vn.create
        rescue => e
          # delete vn in OpenNebula
          call_one_xmlrpc('one.vn.delete', session, vn.oid)
          raise e
        end

        # 3. create leases that belong to the vnet
        begin
          vnet_def[ResourceFile::VirtualNetwork::LEASE].each do |l|
            VNetHandler.
              add_lease_to_vnet(l[ResourceFile::VirtualNetwork::LEASE_NAME],
                                l[ResourceFile::VirtualNetwork::LEASE_ADDRESS],
                                vn)
          end
        rescue => e
          # delete the vnet
          begin; remove_vnet_from_zone(session, vn, zone); rescue; end
          raise e
        end

        # 4. add vnet to the zone
        begin
          zone.add_network(vn.id)
          zone.update
        rescue => e
          # delete the vnet
          begin; remove_vnet_from_zone(session, vn, zone); rescue; end
          raise e
        end

        return vn.id
      end

      # +session+  string that represents user session
      # +vnet+     instance of a vnet
      # +zone+     instance of a zone
      # +return+   id of removed vnet
      def remove_vnet_from_zone(session, vnet, zone)
        if vnet.kind_of?(Integer)
          # vnet is id of virtual network
          id = vnet
          vnet = VirtualNetwork.find_by_id(id)[0]
          raise "VirtualNetwork[#{id}] does not exist." unless vnet
        elsif vnet.kind_of?(String)
          # vnet is name of virtual network
          name = zone.name + ATTR_SEPARATOR + vnet

          vnet = VirtualNetwork.find_by_name(name).last
          raise "VirtualNetwork[#{name}] does not exist." unless vnet
        end

        err_msg = ''

        # 1. remove vnet from the zone
        old_nets = zone.networks_in_array
        zone.remove_network(vnet.id)
        new_nets = zone.networks_in_array
        if old_nets.size > new_nets.size
          zone.update
        else
          err_msg = "VirtualNetwork[#{vnet.unique_name}] is not in Zone[#{zone.name}]."
        end

        # 2. remove leases that belong to the vnet
        vnet.leases_in_array.each do |lid|
          begin
            VNetHandler.remove_lease_from_vnet(lid, vnet)
          rescue => e
            err_msg = (err_msg.size == 0)? e.message : err_msg + '; ' + e.message
          end
        end

        # 3. delete the vnet record
        begin
          vnet.delete
        rescue => e
          err_msg = (err_msg.size == 0)? e.message : err_msg + '; ' + e.message
        end

        # 4. delete vn in OpenNebula
        rc = call_one_xmlrpc('one.vn.delete', session, vnet.oid)
        unless rc[0]
          err_msg = (err_msg.size == 0)? rc[1] : err_msg + '; ' + rc[1]
        end

        raise err_msg unless err_msg.size == 0
        return vnet.id
      end

    end
  end
end


# Local Variables:
# mode: Ruby
# coding: utf-8-unix
# indent-tabs-mode: nil
# End:
