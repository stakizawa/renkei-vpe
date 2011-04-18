require 'renkei-vpe-server/server_role'
require 'renkei-vpe-server/resource_file'
require 'fileutils'
require 'rexml/document'

module RenkeiVPE
  class Zone < ServerRole
    ##########################################################################
    # Define xml rpc interfaces
    ##########################################################################
    INTERFACE = XMLRPC::interface('rvpe.zone') do
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


    ##########################################################################
    # Implement xml rpc functions
    ##########################################################################

    # return information about this zone.
    # +session+   string that represents user session
    # +id+        id of the zone
    # +return[0]+ true or false whenever is successful or not
    # +return[1]+ if an error occurs this is error message,
    #             if successful this is the string with the information
    #             about the zone
    def info(session, id)
      authenticate(session) do
        method_name = 'rvpe.zone.info'

        zone = RenkeiVPE::Model::Zone.find_by_id(id)
        unless zone
          msg = "Zone[#{id}] is not found."
          log_fail_exit(method_name, msg)
          return [false, msg]
        end

        begin
          zone_e = Zone.to_xml_element(zone, session)
          doc = REXML::Document.new
          doc.add(zone_e)
        rescue => e
          log_fail_exit(method_name, e)
          return [false, e.message]
        end

        log_success_exit(method_name)
        return [true, doc.to_s]
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
      authenticate(session, true) do
        method_name = 'rvpe.zone.allocate'

        zone_def = ResourceFile::Parser.load_yaml(template)

        # create a zone
        name = zone_def[ResourceFile::Zone::NAME]
        zone = RenkeiVPE::Model::Zone.find_by_name(name)
        if zone
          msg = "Zone already exists: #{name}"
          log_fail_exit(method_name, msg)
          return [false, msg]
        end
        # create an associated site in OpenNebula
        rc = call_one_xmlrpc('one.cluster.allocate', session, name)
        unless rc[0]
          log_fail_exit(method_name, rc[1])
          return [false, rc[1]]
        end
        osite_id = rc[1]
        # create a zone record
        begin
          zone = RenkeiVPE::Model::Zone.new
          zone.name        = name
          zone.oid         = osite_id
          zone.description = zone_def[ResourceFile::Zone::DESCRIPTION]
          zone.hosts       = ''
          zone.networks    = ''
          zone.create
        rescue => e
          log_fail_exit(method_name, e)
          return [false, e.message]
        end

        # add hosts to this zone
        begin
          zone_def[ResourceFile::Zone::HOST].each do |host|
            rc = add_host_to_zone(session, host, zone)
            raise rc[1] unless rc[0]
          end
        rescue => e
          # delete this zone
          delete(session, zone.id)
          log_fail_exit(method_name, e)
          return [false, e.message]
        end

        # add virtual networks to this zone
        begin
          zone_def[ResourceFile::Zone::NETWORK].each do |net|
            rc = add_vnet_to_zone(session, net, zone)
            raise rc[1] unless rc[0]
          end
        rescue => e
          # delete this zone
          delete(session, zone.id)
          log_fail_exit(method_name, e)
          return [false, e.message]
        end

        log_success_exit(method_name)
        return [true, zone.id]
      end
    end

    # deletes a zone from the zone pool.
    # +session+   string that represents user session
    # +id+        id of the zone
    # +return[0]+ true or false whenever is successful or not
    # +return[1]+ if an error occurs this is error message,
    #             otherwise it does not exist.
    def delete(session, id)
      authenticate(session, true) do
        method_name = 'rvpe.zone.delete'

        zone = RenkeiVPE::Model::Zone.find_by_id(id)
        unless zone
          msg = "Zone[#{id}] does not exist."
          log_fail_exit(method_name, msg)
          return [false, msg]
        end

        err_msg = ''

        # delete virtual networks
        zone.networks.strip.split(/\s+/).map{ |i| i.to_i }.each do |nid|
          rc = remove_vnet_from_zone(session, nid, zone)
          unless rc[0]
            err_msg = (err_msg.size == 0)? rc[1] : err_msg + '; ' + rc[1]
          end
        end

        # delete hosts
        zone.hosts.strip.split(/\s+/).map{ |i| i.to_i }.each do |hid|
          rc = remove_host_from_zone(session, hid, zone)
          unless rc[0]
            err_msg = (err_msg.size == 0)? rc[1] : err_msg + '; ' + rc[1]
          end
        end

        # delete the associated site from OpenNebula
        rc = call_one_xmlrpc('one.cluster.delete', session, zone.oid)
        unless rc[0]
          err_msg = (err_msg.size == 0)? rc[1] : err_msg + '; ' + rc[1]
        end

        # delete zone record
        begin
          zone.delete
        rescue => e
          err_msg = (err_msg.size == 0)? e.message : err_msg + '; ' + e.message
        end

        result = (err_msg.size == 0)? true : false
        rc = [result, err_msg]
        log_result(method_name, rc)
        return rc
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
      authenticate(session, true) do
        method_name = 'rvpe.zone.add_host'

        zone = RenkeiVPE::Model::Zone.find_by_id(id)
        unless zone
          msg = "Zone[#{id}] does not exist."
          log_fail_exit(method_name, msg)
          return [false, msg]
        end

        rc = add_host_to_zone(session, host_name, zone)
        rc[1] = '' if rc[0]
        log_result(method_name, rc)
        return rc
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
      authenticate(session, true) do
        method_name = 'rvpe.zone.remove_host'

        zone = RenkeiVPE::Model::Zone.find_by_id(id)
        unless zone
          msg = "Zone[#{id}] does not exist."
          log_fail_exit(msg)
          return [false, msg]
        end

        rc = remove_host_from_zone(session, host_name, zone)
        rc[1] = '' if rc[0]
        log_result(method_name, rc)
        return rc
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
      authenticate(session, true) do
        method_name = 'rvpe.zone.add_vnet'

        zone = RenkeiVPE::Model::Zone.find_by_id(id)
        unless zone
          msg = "Zone[#{id}] does not exist."
          log_fail_exit(method_name, msg)
          return [false, msg]
        end

        vnet_def = ResourceFile::Parser.load_yaml(template)
        rc = add_vnet_to_zone(session, vnet_def, zone)
        rc[1] = '' if rc[0]
        log_result(method_name, rc)
        return rc
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
      authenticate(session, true) do
        method_name = 'rvpe.zone.remove_vnet'

        zone = RenkeiVPE::Model::Zone.find_by_id(id)
        unless zone
          msg = "Zone[#{id}] does not exist."
          log_fail_exit(msg)
          return [false, msg]
        end

        rc = remove_vnet_from_zone(session, vnet_name, zone)
        rc[1] = '' if rc[0]
        log_result(method_name, rc)
        return rc
      end
    end

    # synchronize probes with remote hosts in all zones.
    # +session+   string that represents user session
    # +return[0]+ always true
    # +return[1]+ always ''
    def sync(session)
      authenticate(session, true) do
        one_loc = ENV['ONE_LOCATION']
        if one_loc
          FileUtils.touch "#{one_loc}/var/remotes"
        else
          FileUtils.touch '/var/lib/one/remotes'
        end
        log_success_exit('rvpe.zone.sync')
        return [true, '']
      end
    end


    private

    # It returns [boolean, integer] or [boolean, string] array.
    # +result[0]+  true if successful, otherwise false
    # +result[1]+  host id in integer if successful, othersize a string
    #              that represents error message
    def add_host_to_zone(session, host_name, zone)
      # allocate host (only in OpenNebula)
      rc = call_one_xmlrpc('one.host.allocate', session,
                           # TODO replace tm_ssh
                           host_name, 'im_kvm', 'vmm_kvm', 'tm_ssh')
      return rc unless rc[0]

      # add the host to a site in OpenNebula
      hid = rc[1]
      rc = call_one_xmlrpc('one.cluster.add', session, hid, zone.oid)
      unless rc[0]
        # delete host
        call_one_xmlrpc('one.host.delete', session, hid)
        return rc
      end

      # add host to the zone
      begin
        zone.hosts = (zone.hosts || '') + "#{hid} "
        zone.update
      rescue => e
        # remove host from site
        call_one_xmlrpc('one.cluster.remove', session, hid)
        # delete host
        call_one_xmlrpc('one.host.delete', session, hid)
        return [false, e.message]
      end

      return [true, hid]
    end

    # It returns [boolean, integer] or [boolean, string] array.
    # +host+       id of host or name of host
    # +result[0]+  true if successful, otherwise false
    # +result[1]+  '' if successful, othersize a string that represents
    #              error message
    def remove_host_from_zone(session, host, zone)
      host_id = host
      if host.kind_of?(String)
        if host.match(/^[0123456789]+$/)
          host_id = host.to_i
        else
          # host is name of host
          zone.hosts.strip.split(/\s+/).map{ |i| i.to_i }.each do |hid|
            rc = call_one_xmlrpc('one.host.info', session, hid)
            doc = REXML::Document.new(rc[1])
            if host == doc.get_text('HOST/NAME').value
              host_id = doc.get_text('HOST/ID').value.to_i
              break
            end
          end
        end

        if host_id.kind_of?(String)
          return [false, "Host[#{host_id}] is not in ZONE[#{zone.name}]."]
        end
      end

      # remove host from the zone
      begin
        old_hosts = zone.hosts.strip.split(/\s+/).map { |i| i.to_i }
        new_hosts = old_hosts - [host_id]
        unless old_hosts.size > new_hosts.size
          raise "Host[#{host_id}] is not in Zone[#{zone.name}]."
        end
        zone.hosts = new_hosts.join(' ') + ' '
        zone.update
      rescue => e
        return [false, e.message]
      end

      err_msg = ''

      # remove the host from a site in OpenNebula
      rc = call_one_xmlrpc('one.cluster.remove', session, host_id)
      unless rc[0]
        err_msg = rc[0]
      end

      # delete the host (only from OpenNebula)
      rc = call_one_xmlrpc('one.host.delete', session, host_id)
      unless rc[0]
        err_msg = (err_msg.size == 0)? rc[1] : err_msg + '; ' + rc[1]
      end

      result = (err_msg.size == 0)? true : false
      return [result, err_msg]
    end

    # It returns [boolean, integer] or [boolean, string] array.
    # +session+    user session
    # +vnet_def+   a hash that stores vnet configuration
    # +zone+       zone the vnet belongs to
    # +result[0]+  true if successful, otherwise false
    # +result[1]+  vnet id in integer if successful, othersize a string
    #              that represents error message
    def add_vnet_to_zone(session, vnet_def, zone)
      name        = vnet_def[ResourceFile::VirtualNetwork::NAME]
      vn_unique   = zone.name + '::' + name

      # 0. check if the vnet already exists
      vnet = RenkeiVPE::Model::VirtualNetwork.find_by_name(vn_unique)
      if vnet
        return [false, "Virtual Network already exists: #{vn_unique}"]
      end

      # 1. allocate vn in OpenNebula
      # create one vnet template
      one_vn_template = <<VN_DEF
NAME   = "#{vn_unique}"
TYPE   = FIXED
PUBLIC = YES

BRIDGE = #{vnet_def[ResourceFile::VirtualNetwork::INTERFACE]}
VN_DEF
      vnet_def[ResourceFile::VirtualNetwork::VHOST].each do |vh|
        one_vn_template +=
          "LEASES = [IP=\"#{vh[ResourceFile::VirtualNetwork::VHOST_ADDRESS]}\"]\n"
      end
      # call rpc
      rc = call_one_xmlrpc('one.vn.allocate', session, one_vn_template)
      return rc unless rc[0]

      # 2. create a vnet
      begin
        vn = RenkeiVPE::Model::VirtualNetwork.new
        vn.oid = rc[1]
        vn.name = name
        vn.description = vnet_def[ResourceFile::VirtualNetwork::DESCRIPTION]
        vn.zone_name   = zone.name
        vn.unique_name = vn_unique
        vn.address     = vnet_def[ResourceFile::VirtualNetwork::ADDRESS]
        vn.netmask     = vnet_def[ResourceFile::VirtualNetwork::NETMASK]
        vn.gateway     = vnet_def[ResourceFile::VirtualNetwork::GATEWAY]
        vn.dns         = vnet_def[ResourceFile::VirtualNetwork::DNS].join(' ')
        vn.ntp         = vnet_def[ResourceFile::VirtualNetwork::NTP].join(' ')
        vn.vhosts      = ''
        vn.create
      rescue => e
        # delete vn in OpenNebula
        call_one_xmlrpc('one.vn.delete', session, vn.oid)
        return [false, e.message]
      end

      # 3. create vhosts that belong to the vnet
      begin
        vnet_def[ResourceFile::VirtualNetwork::VHOST].each do |vh|
          rc =
            add_vhost_to_vnet(vh[ResourceFile::VirtualNetwork::VHOST_NAME],
                              vh[ResourceFile::VirtualNetwork::VHOST_ADDRESS],
                              vn)
          raise rc[1] unless rc[0]
        end
      rescue => e
        # delete the vnet
        remove_vnet_from_zone(session, vn, zone)
        return [false, e.message]
      end

      # 4. add vnet to the zone
      begin
        zone.networks = (zone.networks || '') + "#{vn.id} "
        zone.update
      rescue => e
        # delete the vnet
        remove_vnet_from_zone(session, vn, zone)
        return [false, e.message]
      end

      return [true, vn.id]
    end

    # It returns [boolean, integer] or [boolean, string] array.
    # +vnet+       id of vnet, name of vnet or instance of vnet
    # +result[0]+  true if successful, otherwise false
    # +result[1]+  '' if successful, othersize a string that represents
    #              error message
    def remove_vnet_from_zone(session, vnet, zone)
      if vnet.kind_of?(Integer)
        # vnet is id of virtual network
        id = vnet
        vnet = RenkeiVPE::Model::VirtualNetwork.find_by_id(id)
        unless vnet
          return [false, "Virtual Network[#{id}] does not exist."]
        end
      elsif vnet.kind_of?(String)
        # vnet is name of virtual network
        name = zone.name + '::' + vnet
        vnet = RenkeiVPE::Model::VirtualNetwork.find_by_name(name)
        unless vnet
          return [false, "Virtual Network[#{name}] does not exist."]
        end
      end

      err_msg = ''

      # 1. remove vnet from the zone
      old_nets = zone.networks.strip.split(/\s+/).map { |i| i.to_i }
      new_nets = old_nets - [vnet.id]
      if old_nets.size > new_nets.size
        zone.networks = new_nets.join(' ') + ' '
        zone.update
      else
        err_msg = "VirtualNetwork[#{vnet.unique_name}] is not in Zone[#{zone.name}]."
      end

      # 2. remove vhosts that belong to the vnet
      vhids = vnet.vhosts.strip.split(/\s+/).map { |i| i.to_i }
      vhids.each do |vhid|
        rc = remove_vhost_from_vnet(vhid, vnet)
        unless rc[0]
          err_msg = (err_msg.size == 0)? rc[1] : err_msg + '; ' + rc[1]
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

      result = (err_msg.size == 0)? true : false
      return [result, err_msg]
    end

    # It returns [boolean, integer] or [boolean, string] array.
    # +vhost_name+  name of vhost
    # +vhost_addr+  address of vhost
    # +vnet+        vnet where the vhost belongs
    # +result[0]+   true if successful, otherwise false
    # +result[1]+   vhost id in integer if successful, othersize a string
    #               that represents error message
    def add_vhost_to_vnet(vhost_name, vhost_addr, vnet)
      vh = RenkeiVPE::Model::VirtualHost.find_by_name(vhost_name)
      if vh
        return [false, "VirtualHost[#{vhost_name}] already exists."]
      end

      # create a virtual host record
      begin
        vh = RenkeiVPE::Model::VirtualHost.new
        vh.name      = vhost_name
        vh.address   = vhost_addr
        vh.allocated = 0
        vh.vnetid    = vnet.id.to_i
        vh.create
      rescue => e
        return [false, e.message]
      end

      # update the virtual network record
      begin
        vnet.vhosts = (vnet.vhosts || '') + "#{vh.id} "
        vnet.update
      rescue => e
        # delete vhost
        begin; vh.delete; rescue; end
        return [false, e.message]
      end

      return [true, vh.id]
    end

    # It returns [boolean, integer] or [boolean, string] array.
    # +vhost_id+    id of vhost
    # +vnet+        vnet where the vhost belongs
    # +result[0]+   true if successful, otherwise false
    # +result[1]+   vhost id in integer if successful, othersize a string
    #               that represents error message
    def remove_vhost_from_vnet(vhost_id, vnet)
      vh = RenkeiVPE::Model::VirtualHost.find_by_id(vhost_id)
      unless vh
        return [false, "VirtualHost[#{vhost_id}] does not exist."]
      end

      # remove vhost from the vnet record
      begin
        old_vhosts = vnet.vhosts.strip.split(/\s+/).map { |i| i.to_i }
        new_vhosts = old_vhosts - [vhost_id]
        unless old_vhosts.size > new_vhosts.size
          vnet_un = vnet.zone_name + '::' + vnet.name
          raise "VirtualHost[#{vhost_id}] is not in VirtualNetwork[#{vnet_un}]."
        end
        vnet.vhosts = new_vhosts.join(' ') + ' '
        vnet.update
      rescue => e
        return [false, e.message]
      end

      # remove vhost record
      begin
        vh.delete
      rescue => e
        return [false, e.message]
      end

      return [true, vh.id]
    end


    # It raises an exception when access to one fail
    def self.to_xml_element(zone, one_session)
      # toplevel ZONE element
      zone_e = REXML::Element.new('ZONE')

      # set id
      id_e = REXML::Element.new('ID')
      id_e.add(REXML::Text.new(zone.id.to_s))
      zone_e.add(id_e)

      # set name
      name_e = REXML::Element.new('NAME')
      name_e.add(REXML::Text.new(zone.name))
      zone_e.add(name_e)

      # set hosts
      hosts_e = REXML::Element.new('HOSTS')
      zone_e.add(hosts_e)
      zone.hosts.strip.split(/\s+/).map{ |i| i.to_i }.each do |hid|
        rc = RenkeiVPE::OpenNebulaClient.call_one_xmlrpc('one.host.info',
                                                         one_session,
                                                         hid)
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
      zone.networks.strip.split(/\s+/).map{ |i| i.to_i }.each do |nid|
        vnet = RenkeiVPE::Model::VirtualNetwork.find_by_id(nid)
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

  end
end


# Local Variables:
# mode: Ruby
# coding: utf-8-unix
# indent-tabs-mode: nil
# End:
