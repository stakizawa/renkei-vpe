require 'renkei-vpe-server/server_role'
require 'renkei-vpe-server/resource_file'
require 'rexml/document'

module RenkeiVPE
  class VMType < ServerRole
    ##########################################################################
    # Define xml rpc interfaces
    ##########################################################################
    INTERFACE = XMLRPC::interface('rvpe.vmtype') do
      meth('val info(string, int)',
           'Retrieve information about the vm type',
           'info')
      meth('val allocate(string, string)',
           'Allocates a new vm type',
           'allocate')
      meth('val delete(string, int)',
           'Deletes a vm type from the vm type pool',
           'delete')
    end


    ##########################################################################
    # Implement xml rpc functions
    ##########################################################################

    # return information about this vm type.
    # +session+   string that represents user session
    # +id+        id of the user
    # +return[0]+ true or false whenever is successful or not
    # +return[1]+ if an error occurs this is error message,
    #             if successful this is the string with the information
    #             about the user
    def info(session, id)
      authenticate(session) do
        method_name = 'rvpe.vmtype.info'

        type = RenkeiVPE::Model::VMType.find_by_id(id)
        unless type
          msg = "VMType[#{id}] is not found"
          log_fail_exit(method_name, msg)
          return [false, msg]
        end

        type_e = VMType.to_xml_element(type)
        doc = REXML::Document.new
        doc.add(type_e)

        log_success_exit(method_name)
        return [true, doc.to_s]
      end
    end

    # allocates a new vm type.
    # +session+   string that represents user session
    # +template+  a string containing the template of the vm type
    # +return[0]+ true or false whenever is successful or not
    # +return[1]+ if an error occurs this is the error message,
    #             if successful this is the associated id (int uid)
    #             generated for this vm type
    def allocate(session, template)
      authenticate(session, true) do
        method_name = 'rvpe.vmtype.allocate'

        type_def = ResourceFile::Parser.load_yaml(template)

        name = type_def[ResourceFile::VMType::NAME]
        type = RenkeiVPE::Model::VMType.find_by_name(name)
        if type
          msg = "VM Type already exists: #{name}"
          log_fail_exit(method_name, msg)
          return [false, msg]
        end

        begin
          type = RenkeiVPE::Model::VMType.new
          type.name        = type_def[ResourceFile::VMType::NAME]
          type.cpu         = type_def[ResourceFile::VMType::CPU].to_i
          type.memory      = type_def[ResourceFile::VMType::MEMORY].to_i
          type.description = type_def[ResourceFile::VMType::DESCRIPTION]
          type.create
        rescue => e
          log_fail_exit(method_name, e)
          return [false, e.message]
        end

        log_success_exit(method_name)
        return [true, type.id]
      end
    end

    # deletes a vm type.
    # +session+   string that represents user session
    # +id+        id for the vm type we want to delete
    # +return[0]+ true or false whenever is successful or not
    # +return[1]+ if an error occurs this is error message,
    #             otherwise it does not exist.
    def delete(session, id)
      authenticate(session, true) do
        method_name = 'rvpe.vmtype.delete'

        type = RenkeiVPE::Model::VMType.find_by_id(id)
        unless type
          msg = "VMType[#{id}] does not exist."
          log_fail_exit(method_name, msg)
          return [false, msg]
        end

        begin
          type.delete
        rescue => e
          log_fail_exit(method_name, e)
          return [false, e.message]
        end

        log_success_exit(method_name)
        return [true, '']
      end
    end


    def self.to_xml_element(vm_type)
      # toplevel VM Type element
      type_e = REXML::Element.new('VMTYPE')

      # set id
      id_e = REXML::Element.new('ID')
      id_e.add(REXML::Text.new(vm_type.id.to_s))
      type_e.add(id_e)

      # set name
      name_e = REXML::Element.new('NAME')
      name_e.add(REXML::Text.new(vm_type.name))
      type_e.add(name_e)

      # set cpu
      cpu_e = REXML::Element.new('CPU')
      cpu_e.add(REXML::Text.new(vm_type.cpu.to_s))
      type_e.add(cpu_e)

      # set memory
      mem_e = REXML::Element.new('MEMORY')
      mem_e.add(REXML::Text.new(vm_type.memory.to_s))
      type_e.add(mem_e)

      # set description
      desc_e = REXML::Element.new('DESCRIPTION')
      desc_e.add(REXML::Text.new(vm_type.description))
      type_e.add(desc_e)

      return type_e
    end

  end
end


# Local Variables:
# mode: Ruby
# coding: utf-8-unix
# indent-tabs-mode: nil
# End:
