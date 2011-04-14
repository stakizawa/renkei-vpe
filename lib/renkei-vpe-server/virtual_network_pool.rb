require 'renkei-vpe-server/server_role'
require 'rexml/document'

module RenkeiVPE
  class VirtualNetworkPool < ServerRole
    ##########################################################################
    # Define xml rpc interfaces
    ##########################################################################
    INTERFACE = XMLRPC::interface('rvpe.vnpool') do
      meth('val info(string)',
           'Retrieve information about virtual network pool',
           'info')
    end


    ##########################################################################
    # Implement xml rpc functions
    ##########################################################################

    # return information about host pool.
    # +session+   string that represents user session
    # +return[0]+ true or false whenever is successful or not
    # +return[1]+ if an error occurs this is error message,
    #             if successful this is the information string
    def info(session)
      authenticate(session) do
        pool_e = REXML::Element.new('VNET_POOL')
        begin
          RenkeiVPE::Model::VirtualNetwork.each do |vnet|
            vnet_e = VirtualNetwork.to_xml_element(vnet, session)
            pool_e.add(vnet_e)
          end
          doc = REXML::Document.new
          doc.add(pool_e)
          rc = [true, doc.to_s]
        rescue => e
          rc = [false, e.message]
        end

        log_result('rvpe.vnpool.info', rc)
        return rc
      end
    end
  end
end


# Local Variables:
# mode: Ruby
# coding: utf-8-unix
# indent-tabs-mode: nil
# End:
