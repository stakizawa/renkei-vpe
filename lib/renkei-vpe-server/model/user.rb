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
