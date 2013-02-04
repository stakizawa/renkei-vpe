#
# Copyright 2011-2013 Shinichiro Takizawa
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
  zones   TEXT,
  vm_cnt  INTEGER,
  limits  TEXT,
  uses    TEXT
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
      # [OBSOLETE] number of VM a user can run
      attr_accessor(:vm_cnt)  { |v| v.to_i }
      # number of VMs the user can run on each zone in 'zones'
      attr_accessor :limits
      # number of VMs the user currently runs on each zone in 'zones'
      attr_accessor :uses

      def initialize
        super
        @oid     = -1
        @name    = ''
        @enabled =  1
        @zones   = ''
        @vm_cnt  = -1
        @limits  = ''
        @uses    = ''
      end

      def to_s
        "User<"                  +
          "id=#{@id},"           +
          "oid=#{@oid},"         +
          "name='#{@name}',"     +
          "enabled=#{@enabled}," +
          "zones='#{@zones}',"   +
          "vm_cnt=#{@vm_cnt},"   +
          "limits='#{@limits}'," +
          "uses='#{@uses}'"      +
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

        # set limits
        e = REXML::Element.new('ZONE_LIMITS')
        e.add(REXML::Text.new(@limits))
        user_e.add(e)

        # set uses
        e = REXML::Element.new('ZONE_USES')
        e.add(REXML::Text.new(@uses))
        user_e.add(e)

        return user_e
      end

      # It modifies zones and their limits.
      # +zone_id+  id of zone to be enabled or disabled
      # +enabled+  enable zone if true, otherwise disable zone
      # +limit+    maximum number of VMs the user can run in the zone.
      #            It has effects only when enabled is true.
      def modify_zone(zone_id, enabled, limit)
        zids = zones_in_array
        lmts = limits_in_array

        if enabled
          unless zids.include? zone_id
            zids << zone_id
            lmts << limit
          else
            lmts[zids.index(zone_id)] = limit
          end
        else
          if zids.include? zone_id
            idx = zids.index(zone_id)
            zids.delete_at(idx)
            lmts.delete_at(idx)
          end
        end
        @zones = zids.join(ITEM_SEPARATOR)
        @limits = lmts.join(ITEM_SEPARATOR)
      end

      # It returns an array containing zone ids in integer.
      def zones_in_array
        @zones.strip.split(ITEM_SEPARATOR).map { |i| i.to_i }
      end

      # It returns an array containing limits in each zone in integer.
      def limits_in_array
        @limits.strip.split(ITEM_SEPARATOR).map { |i| i.to_i }
      end

      # It returns an array containing uses in each zone in intger.
      def uses_in_array
        @uses.strip.split(ITEM_SEPARATOR).map { |i| i.to_i }
      end

      def modify_zone_use(zone_id, vm_weight)
        zids = zones_in_array
        if zids.include? zone_id
          idx = zids.index(zone_id)
          uses = uses_in_array
          uses[idx] += vm_weight
          @uses = uses.join(ITEM_SEPARATOR)
        end
      end

      protected

      def check_fields
        raise_if_nil_and_not_class(@oid,     'oid',     Integer)
        raise_if_nil_and_not_class(@name,    'name',    String)
        raise_if_nil_and_not_class(@enabled, 'enabled', Integer)
        raise_if_nil_or_not_class( @zones,   'zones',   String)
        raise_if_nil_and_not_class(@vm_cnt,  'vm_cnt',  Integer)
        raise_if_nil_or_not_class( @limits,  'limits',  String)
        raise_if_nil_or_not_class( @uses,    'uses',    String)
      end

      def to_create_record_str
        "#{@oid},"        +
          "'#{@name}',"   +
          "#{@enabled},"  +
          "'#{@zones}',"  +
          "#{@vm_cnt},"   +
          "'#{@limits}'," +
          "'#{@uses}'"
      end

      def to_find_id_str
        "name='#{@name}'"
      end

      def to_update_record_str
        "oid=#{@oid},"           +
          "name='#{@name}',"     +
          "enabled=#{@enabled}," +
          "zones='#{@zones}',"   +
          "vm_cnt=#{@vm_cnt},"   +
          "limits='#{@limits}'," +
          "uses='#{@uses}'"
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
        return u unless attrs.size == 8
        u.instance_eval do
          @id      = attrs[0].to_i
        end
        u.oid     = attrs[1]
        u.name    = attrs[2]
        u.enabled = attrs[3]
        u.zones   = attrs[4]
        u.vm_cnt  = attrs[5]
        u.limits  = attrs[6]
        u.uses    = attrs[7]
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
