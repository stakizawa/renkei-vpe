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


require 'yaml'

module RenkeiVPETool
  module AdminHelper

    class ResourceGenerator

      def gen_zone(csv_str)
        return YAML.dump(gen_zone_hash(csv_str))
      end

      def gen_vnet(csv_str)
        return YAML.dump(gen_vnet_hash(csv_str))
      end

      def gen_zone_with_vnet(zone_csv_str, *vnet_csv_strs)
        zone_hash = gen_zone_hash(zone_csv_str)
        unless vnet_csv_strs.empty?
          zone_hash['network'] = []
          vnet_csv_strs.each do |e|
            zone_hash['network'] << gen_vnet_hash(e)
          end
        end
        return YAML.dump(zone_hash)
      end

      private

      def gen_zone_hash(csv_str)
        attrs = {}
        csv_str.each_line do |line|
          key,val = line.split(',', 2).map {|e| e.strip}
          case key.upcase
          when 'ZONE_NAME'
            attrs['name'] = val
          when 'DESCRIPTION'
            attrs['description'] = val
          when 'SERVERS'
            attrs['host'] = val.split(',').map {|h| h.strip}
          else
            raise "Unknown attribute: #{key}"
          end
        end
        unless attrs['name']
          raise 'ZONE_NAME attribute is required.'
        end
        return attrs
      end

      def gen_vnet_hash(csv_str)
        attrs = {}
        csv_str.each_line do |line|
          key,val = line.split(',', 2).map {|e| e.strip}
          case key.upcase
          when 'NETWORK_NAME'
            attrs['name'] = val
          when 'DESCRIPTION'
            attrs['description'] = val
          when 'ZONE_NAME'
            ; # do nothing
          when 'ADDRESS'
            attrs['address'] = val
          when 'NETMASK'
            attrs['netmask'] = val
          when 'GATEWAY'
            attrs['gateway'] = val
          when 'DNS_SERVERS'
            attrs['dns'] = val.split(',').map {|h| h.strip}
          when 'NTP_SERVERS'
            attrs['ntp'] = val.split(',').map {|h| h.strip}
          when 'BRIDGE'
            attrs['interface'] = val
          when 'VM_HOSTS'
            attrs['lease'] = []
          else
            if attrs['lease']
              attrs['lease'] << {'name' => key, 'address' => val}
            else
              raise "Unknown attribute: #{key}"
            end
          end
        end
        raise 'NETWORK_NAME attribute is required.' unless attrs['name']
        raise 'ADDRESS attribute is required.'      unless attrs['address']
        raise 'NETMASK attribute is required.'      unless attrs['netmask']
        raise 'GATEWAY attribute is required.'      unless attrs['gateway']
        raise 'DNS_SERVERS attribute is required.'  unless attrs['dns']
        raise 'NTP_SERVERS attribute is required.'  unless attrs['ntp']
        raise 'BRIDGE attribute is required.'       unless attrs['interface']
        raise 'VM_HOSTS attribute is required.'     unless attrs['lease']
        return attrs
      end
    end
  end
end



# Local Variables:
# mode: Ruby
# coding: utf-8
# indent-tabs-mode: nil
# End:
