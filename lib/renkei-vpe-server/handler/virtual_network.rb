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
require 'rexml/document'

module RenkeiVPE
  module Handler

    class VNetHandler < BaseHandler
      ########################################################################
      # Define xml rpc interfaces
      ########################################################################
      INTERFACE = XMLRPC::interface('rvpe.vn') do
        meth('val pool(string)',
             'Retrieve information about virtual network group',
             'pool')
        meth('val ask_id(string, string)',
             'Retrieve id of the given-named virtual network',
             'ask_id')
        meth('val info(string, int)',
             'Retrieve information about the virtual network',
             'info')
        meth('val add_dns(string, int, string)',
             'add new dns servers to the virtual network',
             'add_dns')
        meth('val remove_dns(string, int, string)',
             'remove dns servers from the virtual network',
             'remove_dns')
        meth('val add_ntp(string, int, string)',
             'add new ntp servers to the virtual network',
             'add_ntp')
        meth('val remove_ntp(string, int, string)',
             'remove ntp servers from the virtual network',
             'remove_ntp')
        meth('val add_lease(string, int, string, string)',
             'add a lease to the virtual network',
             'add_lease')
        meth('val remove_lease(string, int, string)',
             'remove a lease from the virtual network',
             'remove_lease')
      end

      ########################################################################
      # Implement xml rpc functions
      ########################################################################

      # return information about virtual network group.
      # +session+   string that represents user session
      # +return[0]+ true or false whenever is successful or not
      # +return[1]+ if an error occurs this is error message,
      #             if successful this is the information string
      def pool(session)
        read_task('rvpe.vn.pool', session) do
          pool_e = REXML::Element.new('VNET_POOL')
          VirtualNetwork.each do |vnet|
            vnet_e = vnet.to_xml_element(session)
            pool_e.add(vnet_e)
          end
          doc = REXML::Document.new
          doc.add(pool_e)
          [true, doc.to_s]
        end
      end

      # return id of the given-named virtual network.
      # +session+   string that represents user session
      # +name+      name of a virtual network
      # +return[0]+ true or false whenever is successful or not
      # +return[1]+ if an error occurs this is error message,
      #             if successful this is the id of the virtual network.
      def ask_id(session, name)
        read_task('rvpe.vn.ask_id', session) do
          vn = VirtualNetwork.find_by_name(name).last
          raise "VirtualNetwork[#{name}] is not found. " unless vn

          [true, vn.id]
        end
      end

      # return information about this virtual network.
      # +session+   string that represents user session
      # +id+        id of the virtual network
      # +return[0]+ true or false whenever is successful or not
      # +return[1]+ if an error occurs this is error message,
      #             if successful this is the string with the information
      #             about the virtual network
      def info(session, id)
        read_task('rvpe.vn.info', session) do
          vnet = VirtualNetwork.find_by_id(id)[0]
          raise "VirtualNetwork[#{id}] is not found." unless vnet

          vnet_e = vnet.to_xml_element(session)
          doc = REXML::Document.new
          doc.add(vnet_e)

          [true, doc.to_s]
        end
      end


      # add dns servers to this virtual network.
      # +session+   string that represents user session
      # +id+        id of the virtual network
      # +dnses+     name of dns servers separated by ' '
      # +return[0]+ true or false whenever is successful or not
      # +return[1]+ if an error occurs this is error message,
      #             otherwise it does not exist.
      def add_dns(session, id, dnses)
        write_task('rvpe.vn.add_dns', session, true) do
          vnet = VirtualNetwork.find_by_id(id)[0]
          raise "VirtualNetwork[#{id}] is not found." unless vnet

          add_servers_to_vnet(vnet, :dns, dnses)
        end
      end

      # remove dns servers from this virtual network.
      # +session+   string that represents user session
      # +id+        id of the zone
      # +dnses+     name of dns servers separated by ' '
      # +return[0]+ true or false whenever is successful or not
      # +return[1]+ if an error occurs this is error message,
      #             otherwise it does not exist.
      def remove_dns(session, id, dnses)
        write_task('rvpe.vn.remove_dns', session, true) do
          vnet = VirtualNetwork.find_by_id(id)[0]
          raise "VirtualNetwork[#{id}] is not found." unless vnet

          remove_servers_from_vnet(vnet, :dns, dnses)
        end
      end

      # add ntp servers to this virtual network.
      # +session+   string that represents user session
      # +id+        id of the virtual network
      # +ntps+      name of ntp servers separated by ' '
      # +return[0]+ true or false whenever is successful or not
      # +return[1]+ if an error occurs this is error message,
      #             otherwise it does not exist.
      def add_ntp(session, id, ntps)
        write_task('rvpe.vn.add_ntp', session, true) do
          vnet = VirtualNetwork.find_by_id(id)[0]
          raise "VirtualNetwork[#{id}] is not found." unless vnet

          add_servers_to_vnet(vnet, :ntp, ntps)
        end
      end

      # remove ntp servers from this virtual network.
      # +session+   string that represents user session
      # +id+        id of the zone
      # +ntps+      name of ntp servers separated by ' '
      # +return[0]+ true or false whenever is successful or not
      # +return[1]+ if an error occurs this is error message,
      #             otherwise it does not exist.
      def remove_ntp(session, id, ntps)
        write_task('rvpe.vn.remove_ntp', session, true) do
          vnet = VirtualNetwork.find_by_id(id)[0]
          raise "VirtualNetwork[#{id}] is not found." unless vnet

          remove_servers_from_vnet(vnet, :ntp, ntps)
        end
      end

      # add a vm lease to this virtual network.
      # +session+   string that represents user session
      # +id+        id of the virtual network
      # +name+      name of the lease, typicaly a server name
      # +ip_addr+   ip address of the lease
      # +return[0]+ true or false whenever is successful or not
      # +return[1]+ if an error occurs this is error message,
      #             otherwise it is the virtual network id.
      def add_lease(session, id, name, ip_addr)
        write_task('rvpe.vn.add_lease', session, true) do
          vnet = VirtualNetwork.find_by_id(id)[0]
          raise "VirtualNetwork[#{id}] is not found." unless vnet

          # TODO check the format of ip_addr

          # create a lease on OpenNebula
          query = "LEASES=[IP=#{ip_addr}]"
          rc = call_one_xmlrpc('one.vn.addleases', session, vnet.oid, query)
          raise rc[1] unless rc[0]

          begin
            VNetHandler.add_lease_to_vnet(name, ip_addr, vnet)
          rescue => e
            call_one_xmlrpc('one.vn.rmleases', session, vnet.oid, query)
            raise e
          end

          [true, vnet.id]
        end
      end

      # remove a vm lease from this virtual network.
      # +session+   string that represents user session
      # +id+        id of the virtual network
      # +name+      name of the lease, typicaly a server name
      # +return[0]+ true or false whenever is successful or not
      # +return[1]+ if an error occurs this is error message,
      #             otherwise it is the virtual network id.
      def remove_lease(session, id, name)
        write_task('rvpe.vn.remove_lease', session, true) do
          vnet = VirtualNetwork.find_by_id(id)[0]
          raise "VirtualNetwork[#{id}] is not found." unless vnet
          l = Lease.find_by_name(name).last
          raise "Lease[#{name}] is not found." unless l
          raise "Lease[#{name}] is used." if l.used == 1
          unless vnet.include_lease?(l.id)
            vnet_un = vnet.zone_name + ATTR_SEPARATOR + vnet.name
            raise "Lease[#{name}] is not included in VirtualNetwork[#{vnet_un}]"
          end

          err_msg = ''
          begin
            VNetHandler.remove_lease_from_vnet(name, vnet)
          rescue => e
            err_msg = (err_msg.size == 0)? e.message : err_msg + '; ' + e.message
          end

          query = "LEASES=[IP=#{l.address}]"
          rc = call_one_xmlrpc('one.vn.rmleases', session, vnet.oid, query)
          unless rc[0]
            err_msg = (err_msg.size == 0)? rc[1] : err_msg + '; ' + rc[1]
          end

          result = (err_msg.size == 0)? true : false
          [result, err_msg]
        end
      end


      # +lease_name+  name of lease
      # +lease_addr+  ip address of lease
      # +vnet+        instance of vnet
      # +return+      id of lease
      def self.add_lease_to_vnet(lease_name, lease_addr, vnet)
        l = Lease.find_by_name(lease_name).last
        raise "Lease[#{lease_name}] already exists." if l

        # create a virtual host record
        l = Lease.new
        l.name    = lease_name
        l.address = lease_addr
        l.vnetid  = vnet.id
        l.create

        # update the virtual network record
        begin
          vnet.add_lease(l.id)
          vnet.update
        rescue => e
          # delete lease
          begin; l.delete; rescue; end
          raise e
        end

        return l.id
      end

      # +lease+     id or name of lease
      # +vnet+      vnet where the lease belongs
      # +return+    lease id in integer
      def self.remove_lease_from_vnet(lease, vnet)
        if lease.kind_of?(Integer)
          l = Lease.find_by_id(lease)[0]
        elsif lease.kind_of?(String)
          l = Lease.find_by_name(lease).last
        end
        raise "Lease[#{lease}] does not exist." unless l

        err_msg = ''

        # remove lease from the vnet record
        begin
          vnet.remove_lease(l.id)
          vnet.update
        rescue => e
          err_msg = (err_msg.size == 0)? e.message : err_msg +'; '+ e.message
        end

        # remove lease record
        begin
          l.delete
        rescue => e
          err_msg = (err_msg.size == 0)? e.message : err_msg +'; '+ e.message
        end

        raise err_msg unless err_msg.size == 0
        return l.id
      end


      private

      # It adds specified servers to the virtual network.
      # It returns [boolean, string] array.
      # +vnet+       target virtual network
      # +type+       type of server in symbol. values are :dns and :ntp
      # +servers+    name of servers separated by ' '
      # +result[0]+  true if successful, otherwise false
      # +result[1]+  '' if successful, othersize a string that represents
      #              error message
      def add_servers_to_vnet(vnet, type, servers)
        new_servers_a = servers.strip.split(/\s+/)
        new_servers_a.each do |s|
          vnet.add_server(type, s)
        end
        vnet.update
        return [true, '']
      end

      # It removes specified servers from the virtual network.
      # It returns [boolean, string] array.
      # +vnet+       target virtual network
      # +type+       type of server in symbol. values are :dns and :ntp
      # +servers+    name of servers separated by ' '
      # +result[0]+  true if successful, otherwise false
      # +result[1]+  '' if successful, othersize a string that represents
      #              error message
      def remove_servers_from_vnet(vnet, type, servers)
        new_servers_a = servers.strip.split(/\s+/)
        new_servers_a.each do |s|
          vnet.remove_server(type, s)
        end
        vnet.update
        return [true, '']
      end

    end
  end
end


# Local Variables:
# mode: Ruby
# coding: utf-8-unix
# indent-tabs-mode: nil
# End:
