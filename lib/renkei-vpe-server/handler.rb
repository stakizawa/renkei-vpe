require 'renkei-vpe-server/handler/base'
require 'renkei-vpe-server/handler/user'
require 'renkei-vpe-server/handler/image'
require 'renkei-vpe-server/handler/zone'
require 'renkei-vpe-server/handler/host'
require 'renkei-vpe-server/handler/virtual_network'
require 'renkei-vpe-server/handler/lease'
require 'renkei-vpe-server/handler/vm_type'
require 'renkei-vpe-server/handler/virtual_machine'

module RenkeiVPE
  ############################################################################
  # Handler module for XML RPC Server
  ############################################################################
  module Handler
    # It sets handlers for the specified rpc_server.
    def init(rpc_server)
      # xml rpc interface
      ifs = [
             [UserHandler::INTERFACE,   UserHandler.new],
             [ImageHandler::INTERFACE,  ImageHandler.new],
             [ZoneHandler::INTERFACE,   ZoneHandler.new],
             [HostHandler::INTERFACE,   HostHandler.new],
             [VNetHandler::INTERFACE,   VNetHandler.new],
             [LeaseHandler::INTERFACE,  LeaseHandler.new],
             [VMTypeHandler::INTERFACE, VMTypeHandler.new],
             [VMHandler::INTERFACE,     VMHandler.new],
            ]

      ifs.each do |iface, obj|
        rpc_server.add_handler(iface, obj)
      end
      # to support system.listMethods, system.methodSignature
      # and system.methodHelp
      rpc_server.add_introspection
      # when method missing and wrong arguments
      rpc_server.set_default_handler do |name, *args|
        raise XMLRPC::FaultException.new(-99, "Method #{name} missing" +
                                         " or wrong number of parameters!")
      end
    end

    module_function :init
  end
end

# Local Variables:
# mode: Ruby
# coding: utf-8-unix
# indent-tabs-mode: nil
# End:
