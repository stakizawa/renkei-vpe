require 'renkei-vpe-server/model/base'

module RenkeiVPE
  ############################################################################
  # A module whose classes store Renkei VPE data
  ############################################################################
  module Model
    ##########################################################################
    # Model for Renkei VPE user
    ##########################################################################
    class User < BaseModel
      @table_name = 'users'

      @table_schema = <<SQL
CREATE TABLE #{@table_name} (
  id      INTEGER PRIMARY KEY AUTOINCREMENT,
  oid     INTEGER UNIQUE,
  name    VARCHAR(256) UNIQUE,
  enabled INTEGER,
  zones   TEXT
);
SQL

      @field_for_find_by_name = 'name'

      # id of the accosiated one user
      attr_accessor(:oid)     { |v| v.to_i }
      # name of the user
      attr_accessor :name
      # a flag, user is enabled(1) or not(0)
      attr_accessor(:enabled) { |v| v.to_i }
      # names of zones the user can use
      attr_accessor :zones

      def initialize
        super
        @oid     = -1
        @name    = ''
        @enabled =  1
        @zones   = ''
      end

      def to_s
        "User<"                  +
          "id=#{@id},"           +
          "oid=#{@oid},"         +
          "name='#{@name}',"     +
          "enabled=#{@enabled}," +
          "zones='#{@zones}'"    +
          ">"
      end

      def to_xml_element(one_session)
        user_e = REXML::Element.new('USER')

        # set id
        e = REXML::Element.new('ID')
        e.add(REXML::Text.new(@id.to_s))
        user_e.add(e)

        # set name
        e = REXML::Element.new('NAME')
        e.add(REXML::Text.new(@name))
        user_e.add(e)

        # set password
        e = REXML::Element.new('PASSWORD')
        rc = call_one_xmlrpc('one.user.info', one_session, @oid)
        if rc[0]
          passwd = REXML::Document.new(rc[1]).elements['USER/PASSWORD'].text.to_s
        else
          passwd = ''
        end
        e.add(REXML::Text.new(passwd))
        user_e.add(e)

        # set enabled
        e = REXML::Element.new('ENABLED')
        e.add(REXML::Text.new(@enabled.to_s))
        user_e.add(e)

        # set zones in id
        e = REXML::Element.new('ZONE_IDS')
        e.add(REXML::Text.new(@zones))
        user_e.add(e)

        # set zones in name
        e = REXML::Element.new('ZONE_NAMES')
        zones = ''
        zones_in_array.each do |zid|
          zone = Zone.find_by_id(zid)[0]
          raise "Zone[#{zid}] is not found." unless zone
          zones += zone.name + ITEM_SEPARATOR
        end
        e.add(REXML::Text.new(zones.chop))
        user_e.add(e)

        return user_e
      end

      # It modifies zones fields.
      # +zone_id+  id of zone to be enabled or disabled
      # +enabled+  enable zone if true, otherwise disable zone
      def modify_zones(zone_id, enabled)
        zids = @zones.strip.split(ITEM_SEPARATOR).map { |i| i.to_i }
        if enabled
          unless zids.include? zone_id
            zids << zone_id
          end
        else
          if zids.include? zone_id
            zids.delete(zone_id)
          end
        end
        @zones = zids.join(ITEM_SEPARATOR)
      end

      # It returns an array containing zone ids in integer.
      def zones_in_array
        @zones.strip.split(ITEM_SEPARATOR).map { |i| i.to_i }
      end

      protected

      def check_fields
        raise_if_nil_and_not_class(@oid,     'oid',     Integer)
        raise_if_nil_and_not_class(@name,    'name',    String)
        raise_if_nil_and_not_class(@enabled, 'enabled', Integer)
        raise_if_nil_or_not_class( @zones,   'zones',   String)
      end

      def to_create_record_str
        "#{@oid},"       +
          "'#{@name}',"  +
          "#{@enabled}," +
          "'#{@zones}'"
      end

      def to_find_id_str
        "name='#{@name}'"
      end

      def to_update_record_str
        "oid=#{@oid},"           +
          "name='#{@name}',"     +
          "enabled=#{@enabled}," +
          "zones='#{@zones}'"
      end

      def self.each(one_session)
        rc = RenkeiVPE::OpenNebulaClient.call_one_xmlrpc('one.userpool.info',
                                                         one_session)
        raise rc[1] unless rc[0]

        doc = REXML::Document.new(rc[1])
        doc.elements.each('USER_POOL/USER') do |e|
          name = e.elements['NAME'].get_text
          user = User.find_by_name(name)[0]
          yield user
        end
      end

      def self.setup_attrs(u, attrs)
        return u unless attrs.size == 5
        u.instance_eval do
          @id      = attrs[0].to_i
        end
        u.oid     = attrs[1]
        u.name    = attrs[2]
        u.enabled = attrs[3]
        u.zones   = attrs[4]
        return u
      end

    end
  end
end


# Local Variables:
# mode: Ruby
# coding: utf-8-unix
# indent-tabs-mode: nil
# End:
