require 'renkei-vpe-server/handler/base'
require 'rexml/document'

module RenkeiVPE
  module Handler

    class VirtualMachinePool < BaseHandler
      ########################################################################
      # Define xml rpc interfaces
      ########################################################################
      INTERFACE = XMLRPC::interface('rvpe.vmpool') do
        meth('val info(string, int, int)',
             'Retrieve information about virtual machine pool',
             'info')
      end


      ########################################################################
      # Implement xml rpc functions
      ########################################################################

      # return information about virtual machine pool.
      # +session+   string that represents user session
      # +flag+      flag for condition
      # +history+   results include previous all VMs info if 1,
      #             otherwize only returns info on current VMs.
      # +return[0]+ true or false whenever is successful or not
      # +return[1]+ if an error occurs this is error message,
      #             if successful this is the information string
      def info(session, flag, history)
        task('rvpe.vmpool.info', session) do
          flag = flag
          if flag <= -2 || flag >= 0
            admin_session(session) do; end
          end

          uname = get_user_from_session(session)
          user = RenkeiVPE::Model::User.find_by_name(uname)[0]

          pool_e = REXML::Element.new('VM_POOL')
          RenkeiVPE::Model::VirtualMachine.each do |vm|
            if flag == -1
              next if vm.user_id != user.id
            elsif flag >= 0
              next if vm.user_id != flag
            end
            vm_e = VirtualMachine.to_xml_element(vm, session)
            stat = vm_e.get_elements('STATE')[0].text.to_i
            next if stat == 6 && history != 1
            pool_e.add(vm_e)
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
