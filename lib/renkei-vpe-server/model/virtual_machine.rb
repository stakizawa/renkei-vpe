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
