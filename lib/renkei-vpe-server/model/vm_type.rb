#
# Copyright 2011-2012 Shinichiro Takizawa
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#


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
  name        VARCHAR(256) UNIQUE,
  cpu         INTEGER,
  memory      INTEGER,
  description TEXT,
  weight      INTEGER
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
      # weight of VM type
      attr_accessor(:weight) { |v| v.to_i }

      def initialize
        super
        @name        = ''
        @cpu         =  0
        @memory      =  0
        @description = ''
        @weight      =  1
      end

      def to_s
        "VMType<"                          +
          "id=#{@id},"                     +
          "name='#{@name}',"               +
          "cpu=#{@cpu},"                   +
          "memory=#{@memory},"             +
          "description='#{@description}'," +
          "weight=#{@weight}"              +
          ">"
      end

      def to_xml_element
        # toplevel VM Type element
        type_e = REXML::Element.new('VMTYPE')

        # set id
        id_e = REXML::Element.new('ID')
        id_e.add(REXML::Text.new(@id.to_s))
        type_e.add(id_e)

        # set name
        name_e = REXML::Element.new('NAME')
        name_e.add(REXML::Text.new(@name))
        type_e.add(name_e)

        # set cpu
        cpu_e = REXML::Element.new('CPU')
        cpu_e.add(REXML::Text.new(@cpu.to_s))
        type_e.add(cpu_e)

        # set memory
        mem_e = REXML::Element.new('MEMORY')
        mem_e.add(REXML::Text.new(@memory.to_s))
        type_e.add(mem_e)

        # set weight
        wei_e = REXML::Element.new('WEIGHT')
        wei_e.add(REXML::Text.new(@weight.to_s))
        type_e.add(wei_e)

        # set description
        desc_e = REXML::Element.new('DESCRIPTION')
        desc_e.add(REXML::Text.new(@description))
        type_e.add(desc_e)

        return type_e
      end

      protected

      def check_fields
        raise_if_nil_and_not_class(@name,        'name',        String)
        raise_if_nil_and_not_class(@cpu,         'cpu',         Integer)
        raise_if_nil_and_not_class(@memory,      'memory',      Integer)
        raise_if_nil_or_not_class( @description, 'description', String)
        raise_if_nil_and_not_class(@weight,      'weight',      Integer)
      end

      def to_create_record_str
        "'#{@name}',"  +
          "#{@cpu},"   +
          "#{@memory}," +
          "'#{@description}'," +
          "#{@weight}"
      end

      def to_find_id_str
        "name='#{@name}'"
      end

      def to_update_record_str
        "name='#{@name}',"    +
          "cpu=#{@cpu},"      +
          "memory=#{@memory}," +
          "description='#{@description}'," +
          "weight=#{@weight}"
      end


      def self.setup_attrs(type, attrs)
        return type unless attrs.size == 6
        type.instance_eval do
          @id            = attrs[0].to_i
        end
        type.name        = attrs[1]
        type.cpu         = attrs[2]
        type.memory      = attrs[3]
        type.description = attrs[4]
        type.weight      = attrs[5]
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
