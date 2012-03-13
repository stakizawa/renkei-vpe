require 'renkei-vpe/pool'

module RenkeiVPE
  class VMTypePool < Pool
    #######################################################################
    # Constants and Class attribute accessors
    #######################################################################

    VMTYPE_POOL_METHODS = {
      :info   => "vmtype.pool",
      :ask_id => "vmtype.ask_id"
    }

    #######################################################################
    # Class constructor & Pool Methods
    #######################################################################

    # +client+ a Client object that represents a XML-RPC connection
    def initialize(client)
      super('VMTYPE_POOL','VMTYPE',client)
    end

    # Factory Method for the VMType Pool
    def factory(element_xml)
      RenkeiVPE::VMType.new(element_xml,@client)
    end

    #######################################################################
    # XML-RPC Methods for the VMType Pool
    #######################################################################

    # Retrieves all the VM types in the pool.
    def info()
      super(VMTYPE_POOL_METHODS[:info])
    end

    # Retrieves the id of the given-named VMType.
    # +name+  name of a VMType
    def ask_id(name)
      super(VMTYPE_POOL_METHODS[:ask_id], name)
    end
  end
end


### Local variables:
### mode: Ruby
### coding: utf-8-unix
### indent-tabs-mode: nil
### End:
