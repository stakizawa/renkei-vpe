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

      attr_accessor :oid        # id of one VM
      attr_accessor :user_id    # id of the VM user
      attr_accessor :zone_id    # id of a zone the VM is located
      attr_accessor :lease_id   # id of virtual machine lease
      attr_accessor :type_id    # id of the VM type
      attr_accessor :image_id   # id of OS image the VM use

      def to_s
        "VirtualMachine<"          +
          "id=#{@id},"             +
          "oid=#{@oid},"           +
          "user_id=#{@user_id},"   +
          "zone_id=#{@zone_id},"   +
          "lease_id=#{@lease_id}," +
          "type_id=#{@type_id},"   +
          "image_id=#{@image_id}," +
          ">"
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
          @oid      = attrs[1].to_i
          @user_id  = attrs[2].to_i
          @zone_id  = attrs[3].to_i
          @lease_id = attrs[4].to_i
          @type_id  = attrs[5].to_i
          @image_id = attrs[6].to_i
        end
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
