require 'renkei-vpe-server/server_role'
require 'fileutils'
require 'rexml/document'
require 'yaml'

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
          msg = "Zone[#{id}] is not found"
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

        zone_def = YAML.load(template)

        # create a zone
        name = zone_def['name']
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
          zone.name = name
          zone.oid  = osite_id
          zone.create
        rescue => e
          log_fail_exit(method_name, e)
          return [false, e.message]
        end

        # add hosts to this zone
        begin
          zone_def['host'].each do |host|
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
        zone_def['network'].each do |net|
          # TODO
          puts "network addition will be implemented"
          pp net
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

        # delete virtual networks from OpenNebula
        zone.networks.split(/\s+/).map{ |i| i.to_i }.each do |nid|
          # TODO implement
          puts "vnet[#{nid}]"
        end

        # delete hosts from OpenNebula
        zone.hosts.split(/\s+/).map{ |i| i.to_i }.each do |hid|
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

        # find host id
        host_id = nil
        zone.hosts.split(/\s+/).map{ |i| i.to_i }.each do |hid|
          rc = call_one_xmlrpc('one.host.info', session, hid)
          doc = REXML::Document.new(rc[1])
          hn = doc.get_text('HOST/NAME').value
          if host_name == hn
            host_id = doc.get_text('HOST/ID').value.to_i
            break
          end
        end

        if host_id
          rc = remove_host_from_zone(session, host_id, zone)
          log_result(method_name, rc)
          return rc
        else
          msg = "Host is not found in ZONE[#{zone.name}]: #{host_name}"
          log_fail_exit(method_name, msg)
          return [false, msg]
        end
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
        # TODO implement
        raise NotImplementedException
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
        # TODO implement
        raise NotImplementedException
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
    # +result[0]+  true if successful, otherwise false
    # +result[1]+  '' if successful, othersize a string that represents
    #              error message
    def remove_host_from_zone(session, host_id, zone)
      # remove host from the zone
      begin
        old_hosts = zone.hosts.split(/\s+/).map { |i| i.to_i }
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


    # It raises an exception when access to one fail
    def self.to_xml_element(zone, one_session)
      # toplevel ZONE element
      zone_e = REXML::Element.new('ZONE')

      # set id
      id_e = REXML::Element.new('ID')
      id_e.add(REXML::Text.new(zone.id))
      zone_e.add(id_e)

      # set name
      name_e = REXML::Element.new('NAME')
      name_e.add(REXML::Text.new(zone.name))
      zone_e.add(name_e)

      # set hosts
      hosts_e = REXML::Element.new('HOSTS')
      zone_e.add(hosts_e)
      zone.hosts.split(/\s+/).map{ |i| i.to_i }.each do |hid|
        rc = RenkeiVPE::OpenNebulaClient.call_one_xmlrpc('one.host.info',
                                                         one_session,
                                                         hid)
        raise rc[1] unless rc[0]

        host_e = REXML::Element.new('HOST')
        host_e.add(REXML::Document.new(rc[1]).get_text('HOST/NAME'))
        hosts_e.add(host_e)
      end

      # set networks
      # TODO implement
      nets_e = REXML::Element.new('NETWORKS')
      nets_e.add(REXML::Text.new('To be implemented'))
      zone_e.add(nets_e)

      return zone_e
    end

  end
end


# Local Variables:
# mode: Ruby
# coding: utf-8-unix
# indent-tabs-mode: nil
# End:
