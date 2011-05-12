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
      DEV_PREFIX  = 'DEV_PREFIX'
      BUS         = 'BUS'
      PATH        = 'PATH'
    end

    ##########################################################################
    # A module that provides parser for each config file.
    ##########################################################################
    module Parser
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
          result = obj
        end
        return result
      end
    end
  end
end


# Local Variables:
# mode: Ruby
# coding: utf-8-unix
# indent-tabs-mode: nil
# End:
