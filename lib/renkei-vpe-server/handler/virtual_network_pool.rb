require 'renkei-vpe-server/handler/base'
require 'rexml/document'

module RenkeiVPE
  module Handler

    class VirtualNetworkPool < BaseHandler
      ########################################################################
      # Define xml rpc interfaces
      ########################################################################
      INTERFACE = XMLRPC::interface('rvpe.vnpool') do
        meth('val info(string)',
             'Retrieve information about virtual network pool',
             'info')
      end


      ########################################################################
      # Implement xml rpc functions
      ########################################################################

      # return information about virtual network pool.
      # +session+   string that represents user session
      # +return[0]+ true or false whenever is successful or not
      # +return[1]+ if an error occurs this is error message,
      #             if successful this is the information string
      def info(session)
        task('rvpe.vpool.info', session) do
          pool_e = REXML::Element.new('VNET_POOL')
          RenkeiVPE::Model::VirtualNetwork.each do |vnet|
            vnet_e = VirtualNetwork.to_xml_element(vnet, session)
            pool_e.add(vnet_e)
          end
          doc = REXML::Document.new
          doc.add(pool_e)
          [true, doc.to_s]
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
