require 'renkei-vpe-server/model/base'

module RenkeiVPE
  ############################################################################
  # A module whose classes store Renkei VPE data
  ############################################################################
  module Model
    ##########################################################################
    # Model for Virtual Machine type
    ##########################################################################
    class VMType < BaseModel
      @table_name = 'vm_types'

      @table_schema = <<SQL
CREATE TABLE #{@table_name} (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  name        VARCHAR(256),
  cpu         INTEGER,
  memory      INTEGER,
  description TEXT
);
SQL

      @field_for_find_by_name = 'name'

      # name of the VM type
      attr_accessor :name
      # number of cpus
      attr_accessor(:cpu)    { |v| v.to_i }
      # amount of memory in MB
      attr_accessor(:memory) { |v| v.to_i }
      # description of the VM type
      attr_accessor :description

      def initialize
        super
        @name        = ''
        @cpu         =  0
        @memory      =  0
        @description = ''
      end

      def to_s
        "VMType<"                         +
          "id=#{@id},"                    +
          "name='#{@name}',"              +
          "cpu=#{@cpu},"                  +
          "memory=#{@memory},"            +
          "description='#{@description}'" +
          ">"
      end

      protected

      def check_fields
        raise_if_nil_and_not_class(@name,        'name',        String)
        raise_if_nil_and_not_class(@cpu,         'cpu',         Integer)
        raise_if_nil_and_not_class(@memory,      'memory',      Integer)
        raise_if_nil_or_not_class( @description, 'description', String)
      end

      def to_create_record_str
        "'#{@name}',"  +
          "#{@cpu},"   +
          "#{@memory}," +
          "'#{@description}'"
      end

      def to_find_id_str
        "name='#{@name}'"
      end

      def to_update_record_str
        "name='#{@name}',"    +
          "cpu=#{@cpu},"      +
          "memory=#{@memory}," +
          "description='#{@description}'"
      end


      def self.setup_attrs(type, attrs)
        return type unless attrs.size == 5
        type.instance_eval do
          @id          = attrs[0].to_i
        end
        type.name        = attrs[1]
        type.cpu         = attrs[2]
        type.memory      = attrs[3]
        type.description = attrs[4]
        return type
      end

    end
  end
end


# Local Variables:
# mode: Ruby
# coding: utf-8-unix
# indent-tabs-mode: nil
# End:
