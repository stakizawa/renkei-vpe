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
    # Model for data transfer session
    ##########################################################################
    class Transfer < BaseModel
      @table_name = 'transfers'

      @table_schema = <<SQL
CREATE TABLE #{@table_name} (
  id   INTEGER PRIMARY KEY AUTOINCREMENT,
  name VARCHAR(256),
  type VARCHAR(256),
  path VARCHAR(256),
  size INTEGER,
  date INTEGER,
  done INTEGER
);
SQL

      @field_for_find_by_name = 'name'

      # name of session
      attr_accessor :name
      # transfer type
      attr_accessor :type
      # server side file path
      attr_accessor :path
      # size to transfer
      attr_accessor(:size) { |v| v.to_i }
      # date when the session created
      attr_reader(:date)

      def initialize
        super
        @name = ''
        @type = ''
        @path = ''
        @size = 0
        @date = Time.now.to_i
        @done = 0
      end

      def to_s
        "Transfer<"          +
          "id=#{@id},"       +
          "name='#{@name}'," +
          "type='#{@type}'," +
          "path='#{@path}'," +
          "size=#{@size},"   +
          "date=#{@date},"   +
          "done=#{@done}"    +
          ">"
      end

      def to_xml_element
        # toplevel Transfer element
        transfer_e = REXML::Element.new('TRANSFER')
        # set name
        name_e = REXML::Element.new('NAME')
        name_e.add(REXML::Text.new(@name))
        transfer_e.add(name_e)
        # set type
        type_e = REXML::Element.new('TYPE')
        type_e.add(REXML::Text.new(@type))
        transfer_e.add(type_e)
        # set size
        size_e = REXML::Element.new('SIZE')
        size_e.add(REXML::Text.new(@size.to_s))
        transfer_e.add(size_e)

        return transfer_e
      end

      def set_done
        if @done == 0
          @done = 1
          update
        end
      end

      def is_done?
        return true if @done == 1
        return false
      end

      protected

      def check_fields
        raise_if_nil_and_not_class(@name, 'name', String)
        raise_if_nil_and_not_class(@type, 'type', String)
        raise_if_nil_and_not_class(@path, 'path', String)
        raise_if_nil_and_not_class(@size, 'size', Integer)
        raise_if_nil_and_not_class(@date, 'date', Integer)
        raise_if_nil_and_not_class(@done, 'done', Integer)
      end

      def to_create_record_str
        "'#{@name}'," +
          "'#{@type}'," +
          "'#{@path}'," +
          "#{@size}," +
          "#{@date}," +
          "#{@done}"
      end

      def to_find_id_str
        "name='#{@name}'"
      end

      def to_update_record_str
        "name='#{@name}',"   +
          "type='#{@type}'," +
          "path='#{@path}'," +
          "size=#{@size},"   +
          "date=#{@date},"   +
          "done=#{@done}"
      end


      def self.setup_attrs(transfer, attrs)
        return transfer unless attrs.size == 7
        transfer.instance_eval do
          @id   = attrs[0].to_i
          @date = attrs[5].to_i
          @done = attrs[6].to_i
        end
        transfer.name = attrs[1]
        transfer.type = attrs[2]
        transfer.path = attrs[3]
        transfer.size = attrs[4]
        return transfer
      end

    end
  end
end


# Local Variables:
# mode: Ruby
# coding: utf-8
# indent-tabs-mode: nil
# End:
