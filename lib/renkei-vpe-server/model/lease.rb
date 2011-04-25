require 'renkei-vpe-server/model/base'

module RenkeiVPE
  ############################################################################
  # A module whose classes store Renkei VPE data
  ############################################################################
  module Model
    ##########################################################################
    # Model for Lease that belongs to a specific Virtual Network
    ##########################################################################
    class Lease < BaseModel
      @table_name = 'leases'

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
        "Lease<"                       +
          "id=#{@id},"                   +
          "name='#{@name}',"             +
          "address='#{@address}',"       +
          "used=#{@used},"               +
          "assigned_to=#{@assigned_to}," +
          "vnetid=#{@vnetid}"            +
          ">"
      end

      def to_xml_element(one_session, onevnet_doc=nil)
        unless onevnet_doc
          # obtain OpenNebula's vnet info
          vnet = VirtualNetwork.find_by_id(@vnetid)[0]
          raise "VirtualNetwork[#{id}] is not found." unless vnet
          rc = call_one_xmlrpc('one.vn.info', one_session, vnet.oid)
          raise rc[1] unless rc[0]
          onevnet_doc = REXML::Document.new(rc[1])
        end

        onel_es = onevnet_doc.get_elements("/VNET/LEASES/LEASE[IP='#{@address}']")
        if onel_es.size != 1
          if onel_es.size == 0
            msg = "DB error: Lease[#{@address}] is defined in RenkeiVPE, but not in OpenNebula."
          else  # >= 1
            msg = "DB error: Lease[#{@address}] is multiply defined in OpenNebula."
          end
          raise msg
        end
        onel_e = onel_es[0]

        # obtain user name
        if @assigned_to >= 0
          user = User.find_by_id(@assigned_to)[0]
          raise "User[#{@assigned_to}] is not found." unless user
          user_name = user.name
        else
          user_name = '-'
        end

        lease_e = REXML::Element.new('LEASE')
        e = REXML::Element.new('ID')
        e.add(REXML::Text.new(@id.to_s))
        lease_e.add(e)
        e = REXML::Element.new('NAME')
        e.add(REXML::Text.new(@name))
        lease_e.add(e)
        e = REXML::Element.new('IP')
        e.add(REXML::Text.new(@address))
        lease_e.add(e)
        e = REXML::Element.new('MAC')
        e.add(onel_e.get_text('MAC'))
        lease_e.add(e)
        e = REXML::Element.new('USED')
        e.add(REXML::Text.new(@used.to_s))
        lease_e.add(e)
        e = REXML::Element.new('ASSIGNED_TO_UID')
        e.add(REXML::Text.new(@assigned_to.to_s))
        lease_e.add(e)
        e = REXML::Element.new('ASSIGNED_TO_UNAME')
        e.add(REXML::Text.new(user_name))
        lease_e.add(e)
        e = REXML::Element.new('VID')
        e.add(onel_e.get_text('VID'))
        lease_e.add(e)
        return lease_e
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
