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
        meth('val allocate(string, string, string, string, string, string)',
             'allocate a new virtual machine',
             'allocate')
        meth('val action(string, int, string)',
             'performe a specified action to the virtual machine',
             'action')
        meth('val mark_save(string, int, string, string)',
             'mark the VM to save its OS image on shutdown',
             'mark_save')
      end

      ########################################################################
      # Implement xml rpc functions
      ########################################################################

      # return information about virtual machine group.
      # +session+   string that represents user session
      # +flag+      flag for condition
      #             if flag <  -1, return all vms
      #             if flag == -1, return mine
      #             if flag >=  0, return user's vms
      # +history+   results include previous all VMs info if 1,
      #             otherwize only returns info on current VMs.
      # +return[0]+ true or false whenever is successful or not
      # +return[1]+ if an error occurs this is error message,
      #             if successful this is the information string
      def pool(session, flag, history)
        read_task('rvpe.vm.pool', session) do
          uname = get_user_from_session(session)
          user = User.find_by_name(uname).last

          if flag <= -2 || (flag >= 0 && flag != user.id)
            admin_session(session) do; end
          end

          # vm search condition
          vm_cond = nil
          if flag == -1
            vm_cond = "user_id=#{user.id}"
          elsif flag >= 0
            vm_cond = "user_id=#{flag}"
          end

          pool_e = REXML::Element.new('VM_POOL')
          VirtualMachine.each(vm_cond) do |vm|
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

      # return id of the latest given-named virtual machine the session
      # owner owns.
      # +session+   string that represents user session
      # +name+      name of a virtual machine
      # +return[0]+ true or false whenever is successful or not
      # +return[1]+ if an error occurs this is error message,
      #             if successful this is the id of the virtual machine.
      def ask_id(session, name)
        read_task('rvpe.vm.ask_id', session) do
          uname = get_user_from_session(session)
          user = User.find_by_name(uname).last
          condition = "user_id=#{user.id} AND name='#{name}'"
          vm = VirtualMachine.find(condition).last
          raise "VirtualMachine[#{name}] is not found." unless vm

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
        read_task('rvpe.vm.info', session) do
          err_msg = "You don't have permission to query info. of the VM."
          sanity_check(session, id, err_msg) do |vm|
            vm_e = vm.to_xml_element(session)
            doc = REXML::Document.new
            doc.add(vm_e)
            [true, doc.to_s]
          end
        end
      end


      # allocate a new virtual machine.
      # +session+   string that represents user session
      # +type_n+    id or name of vm type
      # +image_id+  id of image
      # +sshkey+    ssh public key for root access
      # +zone_n+    id or name of zone
      # +networks+  ids or names of networks and leases
      # +return[0]+ true or false whenever is successful or not
      # +return[1]+ if an error occurs this is error message,
      #             if successful this is the associated id (int id)
      #             generated for this vm
      def allocate(session, type_n, image_id, sshkey, zone_n, networks)
        write_task('rvpe.vm.allocate', session) do
          # 0. get resources and check if they exist
          type = VMType.find_by_id_or_name(type_n).last
          raise "VMType[#{type_n}] is not found." unless type
          zone = Zone.find_by_id_or_name(zone_n).last
          raise "Zone[#{zone_n}] is not found." unless zone

          # 1.   check user limitation & permission
          user_name = get_user_from_session(session)
          user = User.find_by_name(user_name).last
          # 1-1. check if the user has permission to run VMs
          #      in the specified zone
          unless user.zones_in_array.include?(zone.id)
            raise "User[#{user_name}] don't have permission to run VMs " +
              "in Zone[#{zone_n}]."
          end
          # 1-2. check if the user don't overcommit his maximum VM weight
          #      in the specified zone
          user_max = user.limits_in_array[user.zones_in_array.index(zone.id)]
          user_use = user.uses_in_array[user.zones_in_array.index(zone.id)]
          if user_use + type.weight > user_max
            raise "User[#{user_name}] can't run any more VMs " +
              "in Zone[#{zone_n}] as quota reached."
          end

          # 2. get image information
          rc = call_one_xmlrpc('one.image.info', session, image_id)
          raise rc[1] unless rc[0]
          doc = REXML::Document.new(rc[1])
          image_name = doc.elements['/IMAGE/NAME'].get_text.to_s
          if doc.elements['/IMAGE/TEMPLATE/BUS']
            bus_type = doc.elements['/IMAGE/TEMPLATE/BUS'].get_text
            dev_pref = doc.elements['/IMAGE/TEMPLATE/DEV_PREFIX'].get_text
          else
            raise 'BUS and/or DEV_PREFIX attributes are not set to the image.'
          end
          if doc.elements['/IMAGE/TEMPLATE/NIC_MODEL']
            nic_model = doc.elements['/IMAGE/TEMPLATE/NIC_MODEL'].get_text
          else
            raise 'NIC_MODEL attributes is not set to the image.'
          end
          persistent_image = doc.elements['/IMAGE/PERSISTENT'].get_text.to_s
          image_state = doc.elements['/IMAGE/STATE'].get_text.to_s
          if persistent_image == '1' && image_state == '2'
            raise "A persistent image can't be used by two or more VMs."
          end

          # 3. get cluster name from OpenNebula
          rc = call_one_xmlrpc('one.cluster.info', session, zone.oid)
          raise rc[1] unless rc[0]
          doc = REXML::Document.new(rc[1])
          one_cluster = doc.elements['/CLUSTER/NAME'].get_text

          # 4. get network information
          vnets = Array.new
          leases = Array.new
          networks.split(ITEM_SEPARATOR).each do |net_lease|
            net_n,lease_n = net_lease.split(ATTR_SEPARATOR)
            net_fn = zone_n + ATTR_SEPARATOR + net_n

            vnet = VirtualNetwork.find_by_name(net_fn).last
            raise "VirtualNetwork[#{net_fn}] is not found." unless vnet

            if lease_n
              # user specifies a pre-assigned lease
              lease = Lease.find_by_id_or_name(lease_n).last
              unless lease
                raise "Lease[#{lease_n}] is not found."
              end
              if lease.used == 1
                raise "Lease[#{lease.name}] is already used."
              end
              unless lease.assigned_to == user.id
                raise "User[#{user_name}] don't have a permission to use Lease[#{lease.name}]."
              end
              unless lease.vnetid == vnet.id
                raise "Lease[#{lease.name}] can't be used in VirtualNetwork[#{net_fn}]."
              end
            else
              # dynamically assign a new lease
              dyn_leases = vnet.find_available_leases(user.id)
              if dyn_leases.size == 0
                raise "No available virtual host lease in VirtualNetwork[#{net_fn}]."
              end
              lease = dyn_leases[0]
            end

            vnets  << vnet
            leases << lease
          end
          prime_vnet  = vnets[0]
          prime_lease = leases[0]

          # 5. create file paths and ssh public key file
          init_file  = "#{$rvpe_path}/share/vmscripts/init.rb"
          final_file = "#{$rvpe_path}/share/vmscripts/final.rb"
          vmtmpdir   = "#{$rvpe_path}/var/#{prime_lease.name}"
          FileUtils.mkdir_p(vmtmpdir)
          FileUtils.chmod(0750, vmtmpdir)
          ssh_key   = "#{vmtmpdir}/root.pub"
          File.open(ssh_key, 'w+') do |file|
            file.puts sshkey
          end

          # 6. create VM definition file
          vm_def =<<EOS
NAME   = "#{prime_lease.name}"
VCPU   = #{type.cpu}
MEMORY = #{type.memory}

DISK = [
  IMAGE_ID = #{image_id},
  BUS      = "#{bus_type}",
  TARGET   = "#{dev_pref}a",
  DRIVER   = "qcow2"
]

DISK = [
  TYPE   = "swap",
  SIZE   = #{(type.memory * 1.5).to_i},
  TARGET = "vdb"
]

EOS

          vnets.each_with_index do |vnet, i|
            vm_def +=<<EOS
NIC = [
  NETWORK_ID = #{vnet.oid},
  IP         = "#{leases[i].address}",
  MODEL      = "#{nic_model}"
]

EOS
          end

          vm_def +=<<EOS
CONTEXT = [
  HOSTNAME       = "$NAME",
  PRIMARY_IPADDR = "$NIC[ IP, NETWORK_ID=\\"#{prime_vnet.oid}\\" ]",
  NAMESERVERS    = "#{prime_vnet.dns.strip}",
  NTPSERVERS     = "#{prime_vnet.ntp.strip}",
  ETH0_GATEWAY   = "#{prime_vnet.gateway}",
EOS

          vnets.each_with_index do |vnet, i|
            vm_def +=<<EOS
  ETH#{i}_HWADDR    = "$NIC[ MAC, NETWORK_ID=\\"#{vnet.oid}\\" ]",
  ETH#{i}_IPADDR    = "$NIC[ IP, NETWORK_ID=\\"#{vnet.oid}\\" ]",
  ETH#{i}_NETWORK   = "#{vnet.address}",
  ETH#{i}_NETMASK   = "#{vnet.netmask}",
EOS
          end

          vm_def +=<<EOS
  ROOT_PUBKEY    = "root.pub",
  FILES          = "#{init_file} #{final_file} #{ssh_key}",
  TARGET         = "hdc",
  PERSISTENT     = "#{persistent_image}",
  CREATE_DATE    = "#{Time.new.to_i}"
]

REQUIREMENTS = "CLUSTER = \\"#{one_cluster}\\" & FREECPU > #{type.cpu * 100} & FREEMEMORY > #{type.memory}"
RANK = FREECPU

GRAPHICS = [
  TYPE   = "vnc",
  LISTEN = "0.0.0.0",
  PORT   = "-1",
  KEYMAP = "ja"
]
EOS

          # 7. run VM
          rc = call_one_xmlrpc('one.vm.allocate', session, vm_def)
          raise rc[1] unless rc[0]

          # 8. create VM record
          begin
            vm = VirtualMachine.new
            vm.name     = prime_lease.name
            vm.oid      = rc[1]
            vm.user_id  = user.id
            vm.zone_id  = zone.id
            vm.lease_id = prime_lease.id
            vm.type_id  = type.id
            vm.image_id = image_id
            vm.leases   = leases.map{ |l| l.id }.join(ITEM_SEPARATOR)
            vm.info     = VirtualMachine.gen_info_text(user, zone,
                                                       image_id, image_name,
                                                       type, leases)
            vm.create
          rescue => e
            call_one_xmlrpc('one.vm.action', session, 'finalize', rc[1])
            raise e
          end

          # 9-1. create a sym link to OpenNebula VM directory
          one_log_dir = $server_config.one_location + "/var/#{rc[1]}"
          rvpe_link = vmtmpdir + '/one_log'
          FileUtils.ln_s(one_log_dir, rvpe_link)
          # 9-2. create an empty file whose name is vm.id
          FileUtils.touch(vmtmpdir + "/#{vm.id}")

          # 10. finalize
          # 10-1. mark leases as used
          leases.each do |lease|
            begin
              lease.used = 1
              lease.update
            rescue => e
              call_one_xmlrpc('one.vm.action', session, 'finalize', rc[1])
              vm.delete
              FileUtils.rm_rf(vmtmpdir)
              raise e
            end
          end
          # 10-2. update quota use
          begin
            user.modify_zone_use(zone.id, type.weight)
            user.update
          rescue => e
            call_one_xmlrpc('one.vm.action', session, 'finalize', rc[1])
            vm.delete
            FileUtils.rm_rf(vmtmpdir)
            leases.each do |lease|
              lease.used = 0
              lease.update
            end
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
        write_task('rvpe.vm.action', session) do
          err_msg = "You don't have permission to make any action to the VM."
          sanity_check(session, id, err_msg) do |vm|
            rc = call_one_xmlrpc('one.vm.action', session, action, vm.oid)
            raise rc[1] unless rc[0]

            case action.upcase
            when 'SHUTDOWN', 'FINALIZE'
              # delete temporal files
              lease = Lease.find_by_id(vm.lease_id)[0]
              vmtmpdir  = "#{$rvpe_path}/var/#{lease.name}"
              FileUtils.rm_rf(vmtmpdir)
              flg_release_by_this_action = true if lease.used == 1
              # mark leases as not-used
              vm.leases.split(ITEM_SEPARATOR).map { |i| i.to_i }.each do |lid|
                lease = Lease.find_by_id(lid)[0]
                lease.used = 0
                lease.update
              end
              # reduce quota use
              if flg_release_by_this_action
                user = User.find_by_id(vm.user_id).last
                type = VMType.find_by_id(vm.type_id).last
                user.modify_zone_use(vm.zone_id, -type.weight)
                user.update
              end
            end

            rc
          end
        end
      end

      # mark this virtual machine to save its OS image on shutdown.
      # +session+           string that represents user session
      # +id+                id of the virtual machine
      # +image_name+        name of image to be saved
      # +image_description+ description of the image
      # +return[0]+         true or false whenever is successful or not
      # +return[1]+         if an error occurs this is error message,
      #                     otherwise it does not exist.
      def mark_save(session, id, image_name, image_description)
        write_task('rvpe.vm.mark_save', session) do
          err_msg = "You don't have permission to save status of the VM."
          sanity_check(session, id, err_msg) do |vm|
            # It always saves Disk whose ID is 0 (OS image).
            disk_id = 0

            # 1. check if an image whose name is equal to 'image_name' exists
            img = Image.find_by_name(image_name, session, -2).last
            if img
              raise "Image[#{image_name}] already exists.  Use another name."
            end

            # 2. check if the VM is already marked
            rc = call_one_xmlrpc('one.vm.info', session, vm.oid)
            raise rc[1] unless rc[0]
            doc = REXML::Document.new(rc[1])
            xml_prefix = "/VM/TEMPLATE/DISK[DISK_ID=\"#{disk_id}\"]"
            save = doc.elements["#{xml_prefix}/SAVE_AS"]
            if save
              raise "VM[#{vm.id}] is already marked to save its OS image as Image[#{save.text}]"
            end

            # 3. create a template for the saved image
            dev_prefix =
              doc.elements["#{xml_prefix}/TARGET"].get_text.to_s[0, 2]
            bus = doc.elements["#{xml_prefix}/BUS"].get_text.to_s
            nic_model = doc.elements['/VM/TEMPLATE/NIC/MODEL'].get_text.to_s
            template =<<EOS
NAME        = "#{image_name}"
DESCRIPTION = "#{image_description}"
TYPE        = "OS"
BUS         = "#{bus}"
DEV_PREFIX  = "#{dev_prefix}"
NIC_MODEL   = "#{nic_model}"
EOS

            # 4. allocate ONE image
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

      private

      # It checks the VM access permission.
      def sanity_check(session, vm_id, err_msg=nil)
        vm = VirtualMachine.find_by_id(vm_id)[0]
        raise "VirtualMachine[#{vm_id}] is not found." unless vm
        unless vm_is_owned_by_session_owner?(vm, session)
          admin_session(session, true, err_msg) do; end
        end
        yield vm
      end

      # It returns true if the __vm__ is owned by the __session__ owner.
      def vm_is_owned_by_session_owner?(vm, session)
        uname = get_user_from_session(session)
        user = User.find_by_name(uname).last
        if vm.user_id == user.id
          true
        else
          false
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
