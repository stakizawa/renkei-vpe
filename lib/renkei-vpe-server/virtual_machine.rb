require 'renkei-vpe-server/server_role'
require 'rexml/document'
require 'fileutils'

module RenkeiVPE
  class VirtualMachine < ServerRole
    ##########################################################################
    # Define xml rpc interfaces
    ##########################################################################
    INTERFACE = XMLRPC::interface('rvpe.vm') do
      meth('val info(string, int)',
           'Retrieve information about the virtual machine',
           'info')
      meth('val allocate(string, int, int, int, string)',
           'allocate a new virtual machine',
           'allocate')
      meth('val action(string, int, string)',
           'performe a specified action to the virtual machine',
           'action')
      meth('val mark_save(string, int, string)',
           'mark the VM to save its OS image on shutdown',
           'mark_save')
    end


    ##########################################################################
    # Implement xml rpc functions
    ##########################################################################

    # return information about this virtual machine.
    # +session+   string that represents user session
    # +id+        id of the virtual machine
    # +return[0]+ true or false whenever is successful or not
    # +return[1]+ if an error occurs this is error message,
    #             if successful this is the string with the information
    #             about the virtual machine
    def info(session, id)
      task('rvpe.vm.info', session) do
        vm = RenkeiVPE::Model::VirtualMachine.find_by_id(id)[0]
        raise "VirtualMachine[#{id}] is not found." unless vm

        vm_e = VirtualMachine.to_xml_element(vm, session)
        doc = REXML::Document.new
        doc.add(vm_e)
        [true, doc.to_s]
      end
    end


    # allocate a new virtual machine.
    # +session+   string that represents user session
    # +type_id+   id of vm type
    # +zone_id+   id of zone
    # +image_id+  id of image
    # +sshkey+    ssh public key for root access
    # +return[0]+ true or false whenever is successful or not
    # +return[1]+ if an error occurs this is error message,
    #             if successful this is the associated id (int id)
    #             generated for this vm
    def allocate(session, type_id, zone_id, image_id, sshkey)
      task('rvpe.vm.allocate', session) do
        # 0. get user and check if the user has permission to run VMs
        #    in the specified zone
        user_name = get_user_from_session(session)
        user = RenkeiVPE::Model::User.find_by_name(user_name)[0]
        zone_ids = user.zones.split(/\s+/).map { |i| i.to_i }
        unless zone_ids.include?(zone_id)
          raise "User[#{user_name}] don't have permission to use Zone[#{zone_id}]."
        end

        # 1-1. get data about used resources
        type = RenkeiVPE::Model::VMType.find_by_id(type_id)[0]
        zone = RenkeiVPE::Model::Zone.find_by_id(zone_id)[0]
        # FIXME currently only one virtual network is available
        vnet_id = zone.networks.split(/\s+/).map { |i| i.to_i }[0]
        vnet = RenkeiVPE::Model::VirtualNetwork.find_by_id(vnet_id)[0]

        # 1-2. get unused virtual host
        leases = RenkeiVPE::Model::VMLease.find("vnetid=#{vnet.id} AND used=0")
        if leases.size == 0
          raise "No available virtual host lease in Zone[#{zone.name}]."
        end
        lease = leases[0]

        # 1-3. get cluster name from OpenNebula
        rc = call_one_xmlrpc('one.cluster.info', session, zone.oid)
        raise rc[1] unless rc[0]
        doc = REXML::Document.new(rc[1])
        one_cluster = doc.elements['/CLUSTER/NAME'].get_text

        # 2. create file paths and ssh public key file
        init_file = "#{$rvpe_path}/share/vmscripts/centos-5.5/init.rb"
        vmtmpdir  = "#{$rvpe_path}/var/#{lease.name}"
        FileUtils.mkdir_p(vmtmpdir)
        ssh_key   = "#{vmtmpdir}/root.pub"
        File.open(ssh_key, 'w+') do |file|
          file.puts sshkey
        end

        # 3. create VM definition file
        vm_def = <<EOS
NAME   = "#{lease.name}"
VCPU   = #{type.cpu}
MEMORY = #{type.memory}

DISK = [
  IMAGE_ID = #{image_id},
  BUS      = "virtio",
  TARGET   = "vda",
  DRIVER   = "qcow2"
]

DISK = [
  TYPE   = "swap",
  SIZE   = #{(type.memory * 1.5).to_i},
  TARGET = "hdd"
]

NIC = [
  NETWORK_ID = #{vnet.oid},
  IP         = "#{lease.address}",
  MODEL      = "virtio"
]

# GRAPHICS = [
#   TYPE   = "vnc",
#   KEYMAP = "ja"
# ]

CONTEXT = [
  HOSTNAME       = "$NAME",
  PRIMARY_IPADDR = "$NIC[ IP, NETWORK_ID=\\"#{vnet.oid}\\" ]",
  ETH0_HWADDR    = "$NIC[ MAC, NETWORK_ID=\\"#{vnet.oid}\\" ]",
  ETH0_IPADDR    = "$NIC[ IP, NETWORK_ID=\\"#{vnet.oid}\\" ]",
  ETH0_NETWORK   = "#{vnet.address}",
  ETH0_NETMASK   = "#{vnet.netmask}",
  ETH0_GATEWAY   = "#{vnet.gateway}",
  NAMESERVERS    = "#{vnet.dns.strip}",
  NTPSERVERS     = "#{vnet.ntp.strip}",
  ROOT_PUBKEY    = "root.pub",
  FILES          = "#{init_file} #{ssh_key}",
  TARGET         = "hdc",
  CREATE_DATE    = "#{Time.new.to_i}"
]

REQUIREMENTS = "CLUSTER = \\"#{one_cluster}\\""
EOS

        # 4. run VM
        rc = call_one_xmlrpc('one.vm.allocate', session, vm_def)
        raise rc[1] unless rc[0]

        # 5. create VM record
        begin
          vm = RenkeiVPE::Model::VirtualMachine.new(-1, rc[1],
                                                    user.id, zone.id,
                                                    lease.id, type.id, image_id)
          vm.create
        rescue => e
          call_one_xmlrpc('one.vm.action', session, 'finalize', rc[1])
          raise e
        end

        # 6. finalize: mark lease as used
        begin
          lease.used = 1
          lease.update
        rescue => e
          vm.delete
          raise e
        end

        [true, vm.id]
      end
    end

    # performe an action to this virtual machine.
    # +session+   string that represents user session
    # +id+        id of this virtual machine
    # +action+    a string that represents an action
    # +return[0]+ true or false whenever is successful or not
    # +return[1]+ if an error occurs this is error message,
    #             otherwise it does not exist.
    def action(session, id, action)
      task('rvpe.vm.action', session) do
        vm = RenkeiVPE::Model::VirtualMachine.find_by_id(id)[0]
        raise "VirtualMachine[#{id}] is not found." unless vm

        rc = call_one_xmlrpc('one.vm.action', session, action, vm.oid)
        raise rc[1] unless rc[0]

        case action.upcase
        when 'SHUTDOWN', 'FINALIZE'
          # delete temporal files
          lease = RenkeiVPE::Model::VMLease.find_by_id(vm.lease_id)[0]
          vmtmpdir  = "#{$rvpe_path}/var/#{lease.name}"
          FileUtils.rm_rf(vmtmpdir)
          # mark lease as not-used
          lease.used = 0
          lease.update
        end

        rc
      end
    end

    # mark this virtual machine to save its OS image on shutdown.
    # +session+    string that represents user session
    # +id+         id of the virtual machine
    # +image_name+ name of image to be saved
    # +return[0]+  true or false whenever is successful or not
    # +return[1]+  if an error occurs this is error message,
    #              otherwise it does not exist.
    def mark_save(session, id, image_name)
      task('rvpe.vm.mark_save', session) do
        vm = RenkeiVPE::Model::VirtualMachine.find_by_id(id)[0]
        raise "VirtualMachine[#{id}] is not found." unless vm

        # It always saves Disk whose ID is 0 (OS image).
        disk_id = 0
        image_type = 'DISK'
        template =<<EOS
NAME="#{image_name}"
TYPE="OS"
EOS

        # check if the VM is already marked
        rc = call_one_xmlrpc('one.vm.info', session, vm.oid)
        raise rc[1] unless rc[0]
        doc = REXML::Document.new(rc[1])
        save = doc.elements["/VM/TEMPLATE/DISK[DISK_ID=\"#{disk_id}\"]/SAVE_AS"]
        if save
          raise "VM[#{vm.id}] is already marked to save its OS image as Image[#{save.text}]"
        end

        # allocate ONE image
        rc = call_one_xmlrpc('one.image.allocate', session, template)
        raise rc[1] unless rc[0]
        image_id = rc[1]

        begin
          rc = call_one_xmlrpc('one.vm.savedisk', session,
                               vm.oid, disk_id, image_id)
        rescue => e
          call_one_xmlrpc('one.image.delete', session, image_id)
          raise e
        end

        [true, '']
      end
    end


    # It raises an exception when access to one fail
    def self.to_xml_element(vm, one_session)
      # get Data
      no_data_msg = 'Missing, manually deleted.'
      # one vm
      rc = RenkeiVPE::OpenNebulaClient.call_one_xmlrpc('one.vm.info',
                                                       one_session,
                                                       vm.oid)
      raise rc[1] unless rc[0]
      onevm_doc = REXML::Document.new(rc[1])
      # one image
      rc = RenkeiVPE::OpenNebulaClient.call_one_xmlrpc('one.image.info',
                                                       one_session,
                                                       vm.image_id)
      if rc[0]
        oneimg_doc = REXML::Document.new(rc[1])
        image_name = oneimg_doc.elements['/IMAGE/NAME'].get_text
      else
        image_name = no_data_msg
      end
      # from Renkei VPE DB
      user = RenkeiVPE::Model::User.find_by_id(vm.user_id)[0]
      if user
        user_name = user.name
      else
        user_name = no_data_msg
      end
      zone = RenkeiVPE::Model::Zone.find_by_id(vm.zone_id)[0]
      if zone
        zone_name = zone.name
      else
        zone_name = no_data_msg
      end
      lease = RenkeiVPE::Model::VMLease.find_by_id(vm.lease_id)[0]
      if lease
        lease_name = lease.name
        lease_address = lease.address
      else
        lease_name = no_data_msg
        lease_address = no_data_msg
      end
      type = RenkeiVPE::Model::VMType.find_by_id(vm.type_id)[0]
      if zone
        type_name = type.name
      else
        type_name = no_data_msg
      end

      # toplevel VNET element
      vm_e = REXML::Element.new('VM')

      # set id
      e = REXML::Element.new('ID')
      e.add(REXML::Text.new(vm.id.to_s))
      vm_e.add(e)

      # set name
      e = REXML::Element.new('NAME')
      e.add(REXML::Text.new(lease_name))
      vm_e.add(e)

      # set address
      e = REXML::Element.new('ADDRESS')
      e.add(REXML::Text.new(lease_address))
      vm_e.add(e)

      # set user id
      e = REXML::Element.new('USER_ID')
      e.add(REXML::Text.new(vm.user_id.to_s))
      vm_e.add(e)

      # set user name
      e = REXML::Element.new('USER_NAME')
      e.add(REXML::Text.new(user_name))
      vm_e.add(e)

      # set zone id
      e = REXML::Element.new('ZONE_ID')
      e.add(REXML::Text.new(vm.zone_id.to_s))
      vm_e.add(e)

      # set zone name
      e = REXML::Element.new('ZONE_NAME')
      e.add(REXML::Text.new(zone_name))
      vm_e.add(e)

      # set type id
      e = REXML::Element.new('TYPE_ID')
      e.add(REXML::Text.new(vm.type_id.to_s))
      vm_e.add(e)

      # set type name
      e = REXML::Element.new('TYPE_NAME')
      e.add(REXML::Text.new(type_name))
      vm_e.add(e)

      # set image id
      e = REXML::Element.new('IMAGE_ID')
      e.add(REXML::Text.new(vm.image_id.to_s))
      vm_e.add(e)

      # set image name
      e = REXML::Element.new('IMAGE_NAME')
      e.add(REXML::Text.new(image_name))
      vm_e.add(e)

      # set elements from one vm xml
      targets = [
                 '/VM/LAST_POLL',
                 '/VM/STATE',
                 '/VM/LCM_STATE',
                 '/VM/STIME',
                 '/VM/ETIME',
                 '/VM/MEMORY',
                 '/VM/CPU',
                 '/VM/NET_TX',
                 '/VM/NET_RX',
                 '/VM/LAST_SEQ',
                 '/VM/TEMPLATE',
                 '/VM/HISTORY'
                ]
      targets.each do |t|
        e = onevm_doc.elements[t]
        vm_e.add(e) if e
      end

      return vm_e
    end

  end
end


# Local Variables:
# mode: Ruby
# coding: utf-8-unix
# indent-tabs-mode: nil
# End:
