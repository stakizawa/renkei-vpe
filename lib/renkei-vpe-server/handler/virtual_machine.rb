require 'renkei-vpe-server/handler/base'
require 'rexml/document'
require 'fileutils'

module RenkeiVPE
  module Handler

    class VMHandler < BaseHandler
      ########################################################################
      # Define xml rpc interfaces
      ########################################################################
      INTERFACE = XMLRPC::interface('rvpe.vm') do
        meth('val pool(string, int, int)',
             'Retrieve information about virtual machine group',
             'pool')
        meth('val ask_id(string, string)',
             'Retrieve id of the given-named virtual machine',
             'ask_id')
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

      ########################################################################
      # Implement xml rpc functions
      ########################################################################

      # return information about virtual machine group.
      # +session+   string that represents user session
      # +flag+      flag for condition
      # +history+   results include previous all VMs info if 1,
      #             otherwize only returns info on current VMs.
      # +return[0]+ true or false whenever is successful or not
      # +return[1]+ if an error occurs this is error message,
      #             if successful this is the information string
      def pool(session, flag, history)
        task('rvpe.vm.pool', session) do
          flag = flag
          if flag <= -2 || flag >= 0
            admin_session(session) do; end
          end

          uname = get_user_from_session(session)
          user = User.find_by_name(uname)[0]

          pool_e = REXML::Element.new('VM_POOL')
          VirtualMachine.each do |vm|
            if flag == -1
              next if vm.user_id != user.id
            elsif flag >= 0
              next if vm.user_id != flag
            end
            vm_e = vm.to_xml_element(session)
            stat = vm_e.get_elements('STATE')[0].text.to_i
            next if stat == 6 && history != 1
            pool_e.add(vm_e)
          end
          doc = REXML::Document.new
          doc.add(pool_e)
          [true, doc.to_s]
        end
      end

      # return id of the given-named virtual machine.
      # +session+   string that represents user session
      # +name+      name of a virtual machine
      # +return[0]+ true or false whenever is successful or not
      # +return[1]+ if an error occurs this is error message,
      #             if successful this is the id of the virtual machine.
      def ask_id(session, name)
        task('rvpe.vm.ask_id', session) do
          vm = VirtualMachine.find_by_name(name)[0]
          raise "VirtualMachine[#{name}] is not found. " unless vm

          [true, vm.id]
        end
      end

      # return information about this virtual machine.
      # +session+   string that represents user session
      # +id+        id of the virtual machine
      # +return[0]+ true or false whenever is successful or not
      # +return[1]+ if an error occurs this is error message,
      #             if successful this is the string with the information
      #             about the virtual machine
      def info(session, id)
        task('rvpe.vm.info', session) do
          vm = VirtualMachine.find_by_id(id)[0]
          raise "VirtualMachine[#{id}] is not found." unless vm

          vm_e = vm.to_xml_element(session)
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
          user = User.find_by_name(user_name)[0]
          unless user.zones_in_array.include?(zone_id)
            raise "User[#{user_name}] don't have permission to use Zone[#{zone_id}]."
          end

          # 1-1. get data about used resources
          type = VMType.find_by_id(type_id)[0]
          zone = Zone.find_by_id(zone_id)[0]
          # FIXME currently only one virtual network is available
          vnet_id = zone.networks_in_array[0]
          vnet = VirtualNetwork.find_by_id(vnet_id)[0]

          # 1-2. get unused virtual host
          leases = vnet.find_available_leases
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
          vm_def =<<EOS
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
            vm = VirtualMachine.new
            vm.name     = lease.name
            vm.oid      = rc[1]
            vm.user_id  = user.id
            vm.zone_id  = zone.id
            vm.lease_id = lease.id
            vm.type_id  = type.id
            vm.image_id = image_id
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
          vm = VirtualMachine.find_by_id(id)[0]
          raise "VirtualMachine[#{id}] is not found." unless vm

          rc = call_one_xmlrpc('one.vm.action', session, action, vm.oid)
          raise rc[1] unless rc[0]

          case action.upcase
          when 'SHUTDOWN', 'FINALIZE'
            # delete temporal files
            lease = Lease.find_by_id(vm.lease_id)[0]
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
          vm = VirtualMachine.find_by_id(id)[0]
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

    end
  end
end


# Local Variables:
# mode: Ruby
# coding: utf-8-unix
# indent-tabs-mode: nil
# End: