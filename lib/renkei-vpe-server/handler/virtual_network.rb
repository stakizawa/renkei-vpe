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
        task('rvpe.vn.pool', session) do
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
        task('rvpe.vn.ask_id', session) do
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
        task('rvpe.vn.info', session) do
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
        task('rvpe.vn.add_dns', session, true) do
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
        task('rvpe.vn.remove_dns', session, true) do
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
        task('rvpe.vn.add_ntp', session, true) do
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
        task('rvpe.vn.remove_ntp', session, true) do
          vnet = VirtualNetwork.find_by_id(id)[0]
          raise "VirtualNetwork[#{id}] is not found." unless vnet

          remove_servers_from_vnet(vnet, :ntp, ntps)
        end
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
