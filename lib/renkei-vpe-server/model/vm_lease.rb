require 'renkei-vpe-server/model/base'

module RenkeiVPE
  ############################################################################
  # A module whose classes store Renkei VPE data
  ############################################################################
  module Model
    ##########################################################################
    # Model for VM lease that belongs to a specific Virtual Network
    ##########################################################################
    class VMLease < BaseModel
      @table_name = 'vm_leases'

      @table_schema = <<SQL
CREATE TABLE #{@table_name} (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  name        VARCHAR(256),
  address     VARCHAR(256),
  used        INTEGER,
  assigned_to INTEGER,
  vnetid      INTEGER
);
SQL

      @field_for_find_by_name = 'name'

      attr_accessor :name        # name of the vhost lease must be an FQDN
      attr_accessor :address     # IP address of the vhost lease
      attr_accessor :used        # 1 when it is used, othersize 0
      attr_accessor :assigned_to # uid when vm is assigned, othersize -1
      attr_accessor :vnetid      # id of the vnet the vhost belongs to

      def to_s
        "VMLease<"                       +
          "id=#{@id},"                   +
          "name='#{@name}',"             +
          "address='#{@address}',"       +
          "used=#{@used},"               +
          "assigned_to=#{@assigned_to}," +
          "vnetid=#{@vnetid}"            +
          ">"
      end

      protected

      def check_fields
        raise_if_nil_and_not_class(@name,        'name',        String)
        raise_if_nil_and_not_class(@address,     'address',     String)
        raise_if_nil_and_not_class(@used,        'used',        Integer)
        raise_if_nil_and_not_class(@assigned_to, 'assigned_to', Integer)
        raise_if_nil_and_not_class(@vnetid,      'vnetid',      Integer)
      end

      def to_create_record_str
        "'#{@name}',"      +
          "'#{@address}'," +
          "#{@used}," +
          "#{@assigned_to}," +
          "#{@vnetid}"
      end

      def to_find_id_str
        "name='#{@name}'"
      end

      def to_update_record_str
        "name='#{@name}',"           +
          "address='#{@address}',"   +
          "used=#{@used}," +
          "assigned_to=#{@assigned_to}," +
          "vnetid=#{@vnetid}"
      end


      def self.setup_attrs(l, attrs)
        return l unless attrs.size == 6
        l.instance_eval do
          @id          = attrs[0].to_i
          @name        = attrs[1]
          @address     = attrs[2]
          @used        = attrs[3].to_i
          @assigned_to = attrs[4].to_i
          @vnetid      = attrs[5].to_i
        end
        return l
      end

    end
  end
end


# Local Variables:
# mode: Ruby
# coding: utf-8-unix
# indent-tabs-mode: nil
# End:
