require 'renkei-vpe/pool'
require 'OpenNebula'

module RenkeiVPE
  class VirtualMachine < PoolElement
    #######################################################################
    # Constants and Class Methods
    #######################################################################
    VM_METHODS = {
      :info      => 'vm.info',
      :allocate  => 'vm.allocate',
      :action    => 'vm.action',
      :mark_save => 'vm.mark_save'
    }

    VM_STATE             = OpenNebula::VirtualMachine::VM_STATE
    LCM_STATE            = OpenNebula::VirtualMachine::LCM_STATE
    SHORT_VM_STATES      = OpenNebula::VirtualMachine::SHORT_VM_STATES
    SHORT_LCM_STATES     = OpenNebula::VirtualMachine::SHORT_LCM_STATES
    MIGRATE_REASON       = OpenNebula::VirtualMachine::MIGRATE_REASON
    SHORT_MIGRATE_REASON = OpenNebula::VirtualMachine::SHORT_MIGRATE_REASON

    # Creates a VirtualMachine description with just its identifier
    # this method should be used to create plain VirtualMachine objects.
    # +id+ the id of the network
    #
    # Example:
    #   vm = VirtualMachine.new(VirtualMachine.build_xml(3),rpc_client)
    #
    def VirtualMachine.build_xml(pe_id=nil)
      if pe_id
        vn_xml = "<VM><ID>#{pe_id}</ID></VM>"
      else
        vn_xml = "<VM></VM>"
      end

      XMLElement.build_xml(vn_xml, 'VM')
    end

    # Class constructor
    def initialize(xml, client)
      super(xml,client)

      @client = client
    end

    #######################################################################
    # XML-RPC Methods for the Virtual Machine Object
    #######################################################################

    # Retrieves the information of the given VirtualMachine.
    def info()
      super(VM_METHODS[:info], 'VM')
    end

    # Allocates a new VM in RenkeiVPE.
    #
    # +type+   id of VM type
    # +zone+   id of zone where VM will be located
    # +image+  id of image to be used
    # +sshkey+ ssh public key for root access to the VM
    def allocate(type, zone, image, sshkey)
      super(VM_METHODS[:allocate], type, zone, image, sshkey)
    end

    # Do action to the VM.
    #
    # +action+ an action to be performed to the VM
    def action(action)
      return Error.new('ID not defined') if !@pe_id

      rc = @client.call(VM_METHODS[:action], @pe_id, action)
      rc = nil if !RenkeiVPE.is_error?(rc)

      return rc
    end

    # Mark the VM to save its OS image on shutdown.
    def mark_save(image_name)
      return Error.new('ID not defined') if !@pe_id

      rc = @client.call(VM_METHODS[:mark_save], @pe_id, image_name)
      rc = nil if !RenkeiVPE.is_error?(rc)

      return rc
    end


    ##########################################################################
    # Helpers for rpc
    ##########################################################################

    def create(type, zone, image, sshkey)
      rc = allocate(type, zone, image, sshkey)
      return rc if RenkeiVPE.is_error?(rc)
      rc = info
      return rc if RenkeiVPE.is_error?(rc)

      return nil
    end

    def shutdown
      action('shutdown')
    end

    def delete
      action('finalize')
    end

    def restart
      action('restart')
    end

    def suspend
      action('suspend')
    end

    def resume
      action('resume')
    end

    ##########################################################################
    # Helpers to get VirtualMachine information
    ##########################################################################

    # Returns the VM state of the VirtualMachine (numeric value)
    def state
      self['STATE'].to_i
    end

    # Returns the VM state of the VirtualMachine (string value)
    def state_str
      VM_STATE[state]
    end

    # Returns the LCM state of the VirtualMachine (numeric value)
    def lcm_state
      self['LCM_STATE'].to_i
    end

    # Returns the LCM state of the VirtualMachine (string value)
    def lcm_state_str
      LCM_STATE[lcm_state]
    end

    # Returns the short status string for the VirtualMachine
    def status
      short_state_str=SHORT_VM_STATES[state_str]

      if short_state_str=="actv"
        short_state_str=SHORT_LCM_STATES[lcm_state_str]
      end

      short_state_str
    end

  end
end


### Local variables:
### mode: Ruby
### coding: utf-8-unix
### indent-tabs-mode: nil
### End:
