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

module RenkeiVPE

  module ResourceFile

    ##########################################################################
    # A module defines labels for Zone resource file.
    ##########################################################################
    module Zone
      NAME        = 'NAME'
      DESCRIPTION = 'DESCRIPTION'
      HOST        = 'HOST'
      NETWORK     = 'NETWORK'
    end

    ##########################################################################
    # A module defines labels for Virtual Network resource file.
    ##########################################################################
    module VirtualNetwork
      NAME          = 'NAME'
      DESCRIPTION   = 'DESCRIPTION'
      ADDRESS       = 'ADDRESS'
      NETMASK       = 'NETMASK'
      GATEWAY       = 'GATEWAY'
      DNS           = 'DNS'
      NTP           = 'NTP'
      LEASE         = 'LEASE'
      LEASE_NAME    = 'NAME'
      LEASE_ADDRESS = 'ADDRESS'
      INTERFACE     = 'INTERFACE'
    end

    ##########################################################################
    # A module defines labels for VM Type resource file.
    ##########################################################################
    module VMType
      NAME        = 'NAME'
      CPU         = 'CPU'
      MEMORY      = 'MEMORY'
      DESCRIPTION = 'DESCRIPTION'
    end

    ##########################################################################
    # A module defines labels for Image resource file.
    ##########################################################################
    module Image
      NAME        = 'NAME'
      DESCRIPTION = 'DESCRIPTION'
      TYPE        = 'TYPE'
      PUBLIC      = 'PUBLIC'
      PERSISTENT  = 'PERSISTENT'
      IO_BUS      = 'IO_BUS'
      NIC_MODEL   = 'NIC_MODEL'
      PATH        = 'PATH'
    end

    ##########################################################################
    # A module that provides parser for each config file.
    ##########################################################################
    module Parser
      include RenkeiVPE::Const

      # It opens and reads a yaml file to create a hash or array.
      def self.load_yaml_file(file_name)
        conf = YAML.load_file(file_name)
        return to_upcase_yaml_hash_key(conf)
      end

      # It reads a yaml string to create hash or array.
      def self.load_yaml(yaml_string)
        conf = YAML.load(yaml_string)
        return to_upcase_yaml_hash_key(conf)
      end

      def self.to_upcase_yaml_hash_key(obj)
        if obj.kind_of?(Hash)
          result = {}
          obj.each_pair do |k,v|
            result[k.upcase] = to_upcase_yaml_hash_key(v)
          end
        elsif obj.kind_of?(Array)
          result = []
          obj.each do |o|
            result << to_upcase_yaml_hash_key(o)
          end
        else
          result = check_str(obj)
        end
        return result
      end

      def self.check_str(obj)
        return obj unless obj.kind_of?(String)

        blacks = [ITEM_SEPARATOR, ATTR_SEPARATOR]
        blacks.each do |s|
          if obj.include?(s)
            raise "Can't include '#{s}' in resource file: #{obj}"
          end
        end
        return obj
      end

    end
  end
end


# Local Variables:
# mode: Ruby
# coding: utf-8-unix
# indent-tabs-mode: nil
# End:
