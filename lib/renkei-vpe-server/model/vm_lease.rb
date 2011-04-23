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

      # name of the vhost lease must be an FQDN
      attr_accessor :name
      # IP address of the vhost lease
      attr_accessor :address
      # 1 when it is used, othersize 0
      attr_accessor(:used)        { |v| v.to_i }
      # uid when vm is assigned, othersize -1
      attr_accessor(:assigned_to) { |v| v.to_i }
      # id of the vnet the vhost belongs to
      attr_accessor(:vnetid)      { |v| v.to_i }

      def initialize
        super
        @name        = ''
        @address     = ''
        @used        =  0
        @assigned_to = -1
        @vnetid      = -1
      end

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
        "'#{@name}',"        +
          "'#{@address}',"   +
          "#{@used},"        +
          "#{@assigned_to}," +
          "#{@vnetid}"
      end

      def to_find_id_str
        "name='#{@name}'"
      end

      def to_update_record_str
        "name='#{@name}',"               +
          "address='#{@address}',"       +
          "used=#{@used},"               +
          "assigned_to=#{@assigned_to}," +
          "vnetid=#{@vnetid}"
      end


      def self.setup_attrs(l, attrs)
        return l unless attrs.size == 6
        l.instance_eval do
          @id          = attrs[0].to_i
        end
        l.name        = attrs[1]
        l.address     = attrs[2]
        l.used        = attrs[3]
        l.assigned_to = attrs[4]
        l.vnetid      = attrs[5]
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
