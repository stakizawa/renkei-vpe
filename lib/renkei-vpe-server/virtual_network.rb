require 'renkei-vpe-server/server_role'
require 'rexml/document'

module RenkeiVPE
  class VirtualNetwork < ServerRole
    ##########################################################################
    # Define xml rpc interfaces
    ##########################################################################
    INTERFACE = XMLRPC::interface('rvpe.vn') do
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


    ##########################################################################
    # Implement xml rpc functions
    ##########################################################################

    # return information about this virtual network.
    # +session+   string that represents user session
    # +id+        id of the virtual network
    # +return[0]+ true or false whenever is successful or not
    # +return[1]+ if an error occurs this is error message,
    #             if successful this is the string with the information
    #             about the virtual network
    def info(session, id)
      authenticate(session) do
        method_name = 'rvpe.vn.info'

        vnet = RenkeiVPE::Model::VirtualNetwork.find_by_id(id)
        unless vnet
          msg = "VirtualNetwork[#{id}] is not found."
          log_fail_exit(method_name, msg)
          return [false, msg]
        end

        begin
          vnet_e = VirtualNetwork.to_xml_element(vnet, session)
          doc = REXML::Document.new
          doc.add(vnet_e)
        rescue => e
          log_fail_exit(method_name, e)
          return [false, e.message]
        end

        log_success_exit(method_name)
        return [true, doc.to_s]
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
      authenticate(session, true) do
        method_name = 'rvpe.vn.add_dns'

        vnet = RenkeiVPE::Model::VirtualNetwork.find_by_id(id)
        unless vnet
          msg = "VirtualNetwork[#{id}] is not found."
          log_fail_exit(method_name, msg)
          return [false, msg]
        end

        rc = add_servers_to_vnet(vnet, :dns, dnses)
        rc[1] = '' if rc[0]
        log_result(method_name, rc)
        return rc
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
      authenticate(session, true) do
        method_name = 'rvpe.vn.remove_dns'

        vnet = RenkeiVPE::Model::VirtualNetwork.find_by_id(id)
        unless vnet
          msg = "VirtualNetwork[#{id}] is not found."
          log_fail_exit(method_name, msg)
          return [false, msg]
        end

        rc = remove_servers_from_vnet(vnet, :dns, dnses)
        rc[1] = '' if rc[0]
        log_result(method_name, rc)
        return rc
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
      authenticate(session, true) do
        method_name = 'rvpe.vn.add_ntp'

        vnet = RenkeiVPE::Model::VirtualNetwork.find_by_id(id)
        unless vnet
          msg = "VirtualNetwork[#{id}] is not found."
          log_fail_exit(method_name, msg)
          return [false, msg]
        end

        rc = add_servers_to_vnet(vnet, :ntp, ntps)
        rc[1] = '' if rc[0]
        log_result(method_name, rc)
        return rc
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
      authenticate(session, true) do
        method_name = 'rvpe.vn.remove_ntp'

        vnet = RenkeiVPE::Model::VirtualNetwork.find_by_id(id)
        unless vnet
          msg = "VirtualNetwork[#{id}] is not found."
          log_fail_exit(method_name, msg)
          return [false, msg]
        end

        rc = remove_servers_from_vnet(vnet, :ntp, ntps)
        rc[1] = '' if rc[0]
        log_result(method_name, rc)
        return rc
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
      cur_servers = vnet.send(type)

      new_serv_ary = servers.strip.split(/\s+/)
      cur_serv_ary = cur_servers.strip.split(/\s+/)

      new_serv_ary.each do |s|
        unless cur_serv_ary.include? s
          cur_serv_ary << s
        end
      end
      new_servers = cur_serv_ary.join(' ')

      begin
        vnet.send("#{type}=".to_sym, new_servers)
        vnet.update
      rescue => e
        # assume that update of table is failed.
        vnet.send("#{type}=".to_sym, cur_servers)
        return [false, e.message]
      end

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
      cur_servers = vnet.send(type)

      new_serv_ary = servers.strip.split(/\s+/)
      cur_serv_ary = cur_servers.strip.split(/\s+/)

      new_serv_ary.each do |s|
        if cur_serv_ary.include? s
          cur_serv_ary.delete(s)
        end
      end
      new_servers = cur_serv_ary.join(' ')

      begin
        vnet.send("#{type}=".to_sym, new_servers)
        vnet.update
      rescue => e
        # assume that update of table is failed.
        vnet.send("#{type}=".to_sym, cur_servers)
        return [false, e.message]
      end

      return [true, '']
    end


    # It raises an exception when access to one fail
    def self.to_xml_element(vnet, one_session)
      # get one vnet
      rc = RenkeiVPE::OpenNebulaClient.call_one_xmlrpc('one.vn.info',
                                                       one_session,
                                                       vnet.oid)
      raise rc[1] unless rc[0]
      onevn_doc = REXML::Document.new(rc[1])

      # toplevel VNET element
      vnet_e = REXML::Element.new('VNET')

      # set id
      id_e = REXML::Element.new('ID')
      id_e.add(REXML::Text.new(vnet.id.to_s))
      vnet_e.add(id_e)

      # set name
      name_e = REXML::Element.new('NAME')
      name_e.add(REXML::Text.new(vnet.name))
      vnet_e.add(name_e)

      # set zone name
      name_e = REXML::Element.new('ZONE')
      name_e.add(REXML::Text.new(vnet.zone_name))
      vnet_e.add(name_e)

      # set zone name
      name_e = REXML::Element.new('UNIQUE_NAME')
      name_e.add(REXML::Text.new(vnet.unique_name))
      vnet_e.add(name_e)

      # set description
      desc_e = REXML::Element.new('DESCRIPTION')
      desc_e.add(REXML::Text.new(vnet.description))
      vnet_e.add(desc_e)

      # set network address
      addr_e = REXML::Element.new('ADDRESS')
      addr_e.add(REXML::Text.new(vnet.address))
      vnet_e.add(addr_e)

      # set netmask
      mask_e = REXML::Element.new('NETMASK')
      mask_e.add(REXML::Text.new(vnet.netmask))
      vnet_e.add(mask_e)

      # set gateway
      gw_e = REXML::Element.new('GATEWAY')
      gw_e.add(REXML::Text.new(vnet.gateway))
      vnet_e.add(gw_e)

      # set dns servers
      dns_e = REXML::Element.new('DNS')
      dns_e.add(REXML::Text.new(vnet.dns))
      vnet_e.add(dns_e)

      # set ntp servers
      ntp_e = REXML::Element.new('NTP')
      ntp_e.add(REXML::Text.new(vnet.ntp))
      vnet_e.add(ntp_e)

      # set physical host side interface
      if_e = REXML::Element.new('HOST_INTERFACE')
      if_e.add(onevn_doc.get_text('VNET/BRIDGE'))
      vnet_e.add(if_e)


      # set virtual host leases
      vhosts_e = REXML::Element.new('LEASES')
      vnet_e.add(vhosts_e)
      vnet.vhosts.strip.split(/\s+/).map{ |i| i.to_i }.each do |hid|
        not_found_msg = "VirtualHost[#{hid}] is not found."
        vh = RenkeiVPE::Model::VirtualHost.find_by_id(hid)
        raise not_found_msg unless vh
        ovhs = onevn_doc.get_elements("/VNET/LEASES/LEASE[IP='#{vh.address}']")
        if ovhs.size == 0
          raise not_found_msg
        elsif ovhs.size > 1
          raise "Multiple definition of VirtualHost lease: #{vh.address}"
        end
        ovh = ovhs[0]

        id_e = REXML::Element.new('ID')
        id_e.add(REXML::Text.new(hid.to_s))
        name_e = REXML::Element.new('NAME')
        name_e.add(REXML::Text.new(vh.name))
        ip_e = REXML::Element.new('IP')
        ip_e.add(REXML::Text.new(vh.address))
        mac_e = REXML::Element.new('MAC')
        mac_e.add(ovh.get_text('MAC'))
        aloc_e = REXML::Element.new('ALLOCATED')
        aloc_e.add(REXML::Text.new(vh.allocated.to_s))
        vid_e = REXML::Element.new('VID')
        vid_e.add(ovh.get_text('VID'))

        vhost_e = REXML::Element.new('LEASE')
        vhost_e.add(id_e)
        vhost_e.add(name_e)
        vhost_e.add(ip_e)
        vhost_e.add(mac_e)
        vhost_e.add(aloc_e)
        vhost_e.add(vid_e)
        vhosts_e.add(vhost_e)
      end

      return vnet_e
    end

  end
end


# Local Variables:
# mode: Ruby
# coding: utf-8-unix
# indent-tabs-mode: nil
# End:
