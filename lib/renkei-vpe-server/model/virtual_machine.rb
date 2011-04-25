require 'renkei-vpe-server/model/base'

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
  oid         INTEGER UNIQUE,
  user_id     INTEGER,
  zone_id     INTEGER,
  lease_id    INTEGER,
  type_id     INTEGER,
  image_id    INTEGER
);
SQL

      @field_for_find_by_name = 'name'

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

      def initialize
        super
        @oid      = -1
        @user_id  = -1
        @zone_id  = -1
        @lease_id = -1
        @type_id  = -1
        @image_id = -1
      end

      def to_s
        "VirtualMachine<"          +
          "id=#{@id},"             +
          "oid=#{@oid},"           +
          "user_id=#{@user_id},"   +
          "zone_id=#{@zone_id},"   +
          "lease_id=#{@lease_id}," +
          "type_id=#{@type_id},"   +
          "image_id=#{@image_id}"  +
          ">"
      end

      def to_xml_element(one_session)
        # get Data
        no_data_msg = 'Missing, manually deleted.'
        # one vm
        rc = call_one_xmlrpc('one.vm.info', one_session, @oid)
        raise rc[1] unless rc[0]
        onevm_doc = REXML::Document.new(rc[1])
        # one image
        rc = call_one_xmlrpc('one.image.info', one_session, @image_id)
        if rc[0]
          oneimg_doc = REXML::Document.new(rc[1])
          image_name = oneimg_doc.elements['/IMAGE/NAME'].get_text
        else
          image_name = no_data_msg
        end
        # from Renkei VPE DB
        user = User.find_by_id(@user_id)[0]
        if user
          user_name = user.name
        else
          user_name = no_data_msg
        end
        zone = Zone.find_by_id(@zone_id)[0]
        if zone
          zone_name = zone.name
        else
          zone_name = no_data_msg
        end
        lease = Lease.find_by_id(@lease_id)[0]
        if lease
          lease_name = lease.name
          lease_address = lease.address
        else
          lease_name = no_data_msg
          lease_address = no_data_msg
        end
        type = VMType.find_by_id(@type_id)[0]
        if zone
          type_name = type.name
        else
          type_name = no_data_msg
        end

        # toplevel VNET element
        vm_e = REXML::Element.new('VM')

        # set id
        e = REXML::Element.new('ID')
        e.add(REXML::Text.new(@id.to_s))
        vm_e.add(e)

        # set name
        e = REXML::Element.new('NAME')
        e.add(REXML::Text.new(lease_name))
        vm_e.add(e)

        # set address
        e = REXML::Element.new('ADDRESS')
        e.add(REXML::Text.new(lease_address))
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

        # set elements from one vm xml
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

      protected

      def check_fields
        raise_if_nil_and_not_class(@oid,      'oid',      Integer)
        raise_if_nil_and_not_class(@user_id,  'user_id',  Integer)
        raise_if_nil_and_not_class(@zone_id,  'zone_id',  Integer)
        raise_if_nil_and_not_class(@lease_id, 'lease_id', Integer)
        raise_if_nil_and_not_class(@type_id,  'type_id',  Integer)
        raise_if_nil_and_not_class(@image_id, 'image_id', Integer)
      end

      def to_create_record_str
        "#{@oid},"        +
          "#{@user_id},"  +
          "#{@zone_id},"  +
          "#{@lease_id}," +
          "#{@type_id},"  +
          "#{@image_id}"
      end

      def to_find_id_str
        "oid=#{@oid}"
      end

      def to_update_record_str
        "oid=#{@oid},"             +
          "user_id=#{@user_id},"   +
          "zone_id=#{@zone_id},"   +
          "lease_id=#{@lease_id}," +
          "type_id=#{@type_id},"   +
          "image_id=#{@image_id}"
      end

      def self.setup_attrs(vm, attrs)
        return vm unless attrs.size == 7
        vm.instance_eval do
          @id       = attrs[0].to_i
        end
        vm.oid      = attrs[1]
        vm.user_id  = attrs[2]
        vm.zone_id  = attrs[3]
        vm.lease_id = attrs[4]
        vm.type_id  = attrs[5]
        vm.image_id = attrs[6]
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
