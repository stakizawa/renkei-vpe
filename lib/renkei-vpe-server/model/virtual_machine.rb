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
require 'yaml'

module RenkeiVPE
  ############################################################################
  # A module whose classes store Renkei VPE data
  ############################################################################
  module Model
    ##########################################################################
    # Model for Virtual Machine
    ##########################################################################
    class VirtualMachine < BaseModel
      @table_name = 'virtual_machines'

      @table_schema = <<SQL
CREATE TABLE #{@table_name} (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  name        VARCHAR(256),
  oid         INTEGER UNIQUE,
  user_id     INTEGER,
  zone_id     INTEGER,
  lease_id    INTEGER,
  type_id     INTEGER,
  image_id    INTEGER,
  leases      VARCHAR(256),
  info        TEXT
);
SQL

      @field_for_find_by_name = 'name'

      # name of VM
      attr_accessor(:name)
      # id of one VM
      attr_accessor(:oid)      { |v| v.to_i }
      # id of the VM user
      attr_accessor(:user_id)  { |v| v.to_i }
      # id of a zone the VM is located
      attr_accessor(:zone_id)  { |v| v.to_i }
      # id of virtual machine lease
      attr_accessor(:lease_id) { |v| v.to_i }
      # id of the VM type
      attr_accessor(:type_id)  { |v| v.to_i }
      # id of OS image the VM use
      attr_accessor(:image_id) { |v| v.to_i }
      # ids of all leases the VM use
      attr_accessor(:leases)
      # information of the VM
      attr_accessor(:info)

      def initialize
        super
        @name     = ''
        @oid      = -1
        @user_id  = -1
        @zone_id  = -1
        @lease_id = -1
        @type_id  = -1
        @image_id = -1
        @leases   = ''
        @info     = ''
      end

      def to_s
        "VirtualMachine<"          +
          "name=#{@name},"         +
          "id=#{@id},"             +
          "oid=#{@oid},"           +
          "user_id=#{@user_id},"   +
          "zone_id=#{@zone_id},"   +
          "lease_id=#{@lease_id}," +
          "type_id=#{@type_id},"   +
          "image_id=#{@image_id}," +
          "leases=#{@leases},"     +
          "info=#{@info}"          +
          ">"
      end

      def to_xml_element(one_session)
        # get Data
        data = YAML.load(@info)
        no_data_msg = 'Missing, manually deleted.'
        # user name
        if data.instance_of?(Hash) && data['USER']['NAME']
          user_name = data['USER']['NAME']
        else
          # for supporting old version
          user = User.find_by_id(@user_id)[0]
          if user
            user_name = user.name
          else
            user_name = no_data_msg
          end
        end
        # zone name
        if data.instance_of?(Hash) && data['ZONE']['NAME']
          zone_name = data['ZONE']['NAME']
        else
          # for supporting old version
          zone = Zone.find_by_id(@zone_id)[0]
          if zone
            zone_name = zone.name
          else
            zone_name = no_data_msg
          end
        end
        # image name
        if data.instance_of?(Hash) && data['IMAGE']['NAME']
          image_name = data['IMAGE']['NAME']
        else
          # for supporting old version
          rc = call_one_xmlrpc('one.image.info', one_session, @image_id)
          if rc[0]
            oneimg_doc = REXML::Document.new(rc[1])
            image_name = oneimg_doc.elements['/IMAGE/NAME'].get_text
          else
            image_name = no_data_msg
          end
        end
        # vm type name
        if data.instance_of?(Hash) && data['TYPE']['NAME']
          type_name = data['TYPE']['NAME']
        else
          # for supporting old version
          type = VMType.find_by_id(@type_id)[0]
          if type
            type_name = type.name
          else
            type_name = no_data_msg
          end
        end
        # prime lease name & address
        if data.instance_of?(Hash) && data['LEASES'][0]
          prime_lease_name = data['LEASES'][0]['NAME']
          prime_lease_address = data['LEASES'][0]['ADDRESS']
        else
          # for supporting old version
          prime_lease_name = @name
          l = Lease.find_by_name(@name)[0]
          if l
            prime_lease_address = l.address
          else
            prime_lease_address = no_data_msg
          end
        end

        # toplevel VNET element
        vm_e = REXML::Element.new('VM')

        # set id
        e = REXML::Element.new('ID')
        e.add(REXML::Text.new(@id.to_s))
        vm_e.add(e)

        # set name
        e = REXML::Element.new('NAME')
        e.add(REXML::Text.new(prime_lease_name))
        vm_e.add(e)

        # set address
        e = REXML::Element.new('ADDRESS')
        e.add(REXML::Text.new(prime_lease_address))
        vm_e.add(e)

        # set user id
        e = REXML::Element.new('USER_ID')
        e.add(REXML::Text.new(@user_id.to_s))
        vm_e.add(e)

        # set user name
        e = REXML::Element.new('USER_NAME')
        e.add(REXML::Text.new(user_name))
        vm_e.add(e)

        # set zone id
        e = REXML::Element.new('ZONE_ID')
        e.add(REXML::Text.new(@zone_id.to_s))
        vm_e.add(e)

        # set zone name
        e = REXML::Element.new('ZONE_NAME')
        e.add(REXML::Text.new(zone_name))
        vm_e.add(e)

        # set type id
        e = REXML::Element.new('TYPE_ID')
        e.add(REXML::Text.new(@type_id.to_s))
        vm_e.add(e)

        # set type name
        e = REXML::Element.new('TYPE_NAME')
        e.add(REXML::Text.new(type_name))
        vm_e.add(e)

        # set image id
        e = REXML::Element.new('IMAGE_ID')
        e.add(REXML::Text.new(@image_id.to_s))
        vm_e.add(e)

        # set image name
        e = REXML::Element.new('IMAGE_NAME')
        e.add(REXML::Text.new(image_name))
        vm_e.add(e)

        # set all leases
        ls_e = REXML::Element.new('LEASES')
        if data.instance_of?(Hash) && data['LEASES']
          data['LEASES'].each do |l|
            lid   = l['ID']
            lname = l['NAME']
            laddr = l['ADDRESS']

            l_e = REXML::Element.new('LEASE')
            e = REXML::Element.new('ID')
            e.add(REXML::Text.new(lid.to_s))
            l_e.add(e)
            e = REXML::Element.new('NAME')
            e.add(REXML::Text.new(lname))
            l_e.add(e)
            e = REXML::Element.new('ADDRESS')
            e.add(REXML::Text.new(laddr))
            l_e.add(e)
            ls_e.add(l_e)
          end
        else
          # for supporting old version
          @leases.split(ITEM_SEPARATOR).map{ |i| i.to_i }.each do |lid|
            l = Lease.find_by_id(lid)[0]
            if l
              lname = l.name
              laddr = l.address
            else
              lname = no_data_msg
              laddr = no_data_msg
            end

            l_e = REXML::Element.new('LEASE')
            e = REXML::Element.new('ID')
            e.add(REXML::Text.new(lid.to_s))
            l_e.add(e)
            e = REXML::Element.new('NAME')
            e.add(REXML::Text.new(lname))
            l_e.add(e)
            e = REXML::Element.new('ADDRESS')
            e.add(REXML::Text.new(laddr))
            l_e.add(e)
            ls_e.add(l_e)
          end
        end
        vm_e.add(ls_e)

        # set elements from one vm xml
        rc = call_one_xmlrpc('one.vm.info', one_session, @oid)
        raise rc[1] unless rc[0]
        onevm_doc = REXML::Document.new(rc[1])
        targets = [
                   '/VM/LAST_POLL',
                   '/VM/STATE',
                   '/VM/LCM_STATE',
                   '/VM/STIME',
                   '/VM/ETIME',
                   '/VM/MEMORY',
                   '/VM/CPU',
                   '/VM/NET_TX',
                   '/VM/NET_RX',
                   '/VM/LAST_SEQ',
                   '/VM/TEMPLATE',
                   '/VM/HISTORY'
                  ]
        targets.each do |t|
          e = onevm_doc.elements[t]
          vm_e.add(e) if e
        end

        return vm_e
      end

      # It generates text for info field.
      def self.gen_info_text(user, zone, image_id, image_name, type, leases)
        info = {}
        info['USER'] = {}
        info['USER']['ID'] = user.id
        info['USER']['NAME'] = user.name
        info['ZONE'] = {}
        info['ZONE']['ID'] = zone.id
        info['ZONE']['NAME'] = zone.name
        info['IMAGE'] = {}
        info['IMAGE']['ID'] = image_id
        info['IMAGE']['NAME'] = image_name
        info['TYPE'] = {}
        info['TYPE']['ID'] = type.id
        info['TYPE']['NAME'] = type.name

        info['LEASES'] = []
        leases.each do |l|
          lh = {}
          lh['ID'] = l.id
          lh['NAME'] = l.name
          lh['ADDRESS'] = l.address
          info['LEASES'] << lh
        end

        return YAML.dump(info)
      end

      protected

      def check_fields
        raise_if_nil_and_not_class(@name,     'name',     String)
        raise_if_nil_and_not_class(@oid,      'oid',      Integer)
        raise_if_nil_and_not_class(@user_id,  'user_id',  Integer)
        raise_if_nil_and_not_class(@zone_id,  'zone_id',  Integer)
        raise_if_nil_and_not_class(@lease_id, 'lease_id', Integer)
        raise_if_nil_and_not_class(@type_id,  'type_id',  Integer)
        raise_if_nil_and_not_class(@image_id, 'image_id', Integer)
        raise_if_nil_and_not_class(@leases,   'leases',   String)
        raise_if_nil_and_not_class(@leases,   'info',     String)
      end

      def to_create_record_str
        "'#{@name}',"     +
          "#{@oid},"      +
          "#{@user_id},"  +
          "#{@zone_id},"  +
          "#{@lease_id}," +
          "#{@type_id},"  +
          "#{@image_id}," +
          "'#{@leases}'," +
          "'#{@info}'"
      end

      def to_find_id_str
        "name='#{@name}'"
      end

      def to_update_record_str
        "name='#{@name}',"         +
          "oid=#{@oid},"           +
          "user_id=#{@user_id},"   +
          "zone_id=#{@zone_id},"   +
          "lease_id=#{@lease_id}," +
          "type_id=#{@type_id},"   +
          "image_id=#{@image_id}," +
          "leases='#{@leases}',"   +
          "info='#{@info}'"
      end

      def self.setup_attrs(vm, attrs)
        return vm unless attrs.size == 10
        vm.instance_eval do
          @id       = attrs[0].to_i
        end
        vm.name     = attrs[1]
        vm.oid      = attrs[2]
        vm.user_id  = attrs[3]
        vm.zone_id  = attrs[4]
        vm.lease_id = attrs[5]
        vm.type_id  = attrs[6]
        vm.image_id = attrs[7]
        vm.leases   = attrs[8] || ''
        vm.info     = attrs[9] || ''
        return vm
      end

    end
  end
end


# Local Variables:
# mode: Ruby
# coding: utf-8-unix
# indent-tabs-mode: nil
# End:
