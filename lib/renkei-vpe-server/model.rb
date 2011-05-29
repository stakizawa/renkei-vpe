require 'renkei-vpe-server/model/base'
require 'renkei-vpe-server/model/user'
require 'renkei-vpe-server/model/virtual_machine'
require 'renkei-vpe-server/model/virtual_network'
require 'renkei-vpe-server/model/lease'
require 'renkei-vpe-server/model/vm_type'
require 'renkei-vpe-server/model/zone'

module RenkeiVPE
  module Model
    # It initializes model classes.
    def init(db_file)
      Database.file = db_file

      unless FileTest.exist?(Database.file)
        FileUtils.touch(Database.file)
        FileUtils.chmod(0640, Database.file)
      end

      User.create_table_if_necessary
      Zone.create_table_if_necessary
      VirtualNetwork.create_table_if_necessary
      Lease.create_table_if_necessary
      VMType.create_table_if_necessary
      VirtualMachine.create_table_if_necessary
    end

    module_function :init
  end
end


# Local Variables:
# mode: Ruby
# coding: utf-8-unix
# indent-tabs-mode: nil
# End:
