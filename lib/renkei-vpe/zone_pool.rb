require 'renkei-vpe/pool'

module RenkeiVPE
  class ZonePool < Pool
    #######################################################################
    # Constants and Class attribute accessors
    #######################################################################

    ZONE_POOL_METHODS = {
      :info   => "zone.pool",
      :ask_id => "zone.ask_id"
    }

    #######################################################################
    # Class constructor & Pool Methods
    #######################################################################

    # +client+ a Client object that represents a XML-RPC connection
    def initialize(client)
      super('ZONE_POOL','ZONE',client)
    end

    # Factory method to create Zone objects
    def factory(element_xml)
      RenkeiVPE::Zone.new(element_xml,@client)
    end

    #######################################################################
    # XML-RPC Methods for the Zone Object
    #######################################################################

    # Retrieves all the Zones in the pool.
    def info()
      super(ZONE_POOL_METHODS[:info])
    end

    # Retrieves the id of the given-named zone.
    # +name+  name of a zone
    def ask_id(name)
      super(ZONE_POOL_METHODS[:ask_id], name)
    end
  end
end


### Local variables:
### mode: Ruby
### coding: utf-8-unix
### indent-tabs-mode: nil
### End:
