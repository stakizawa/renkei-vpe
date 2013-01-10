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


module RenkeiVPETool
  module CliUtilities

    #########################################################################
    # Functions for command line parsing
    #########################################################################

    def exit_on_parse_error(errmsg=nil)
      $stderr.puts errmsg if errmsg
      $stderr.puts
      $stderr.puts "Run '#{CMD_NAME} help' to see the usage."
      exit 1
    end

    def check_command(name, number)
      if ARGV.length < number
        $stderr.print "Error: Command #{name} requires "
        if number > 1
          $stderr.puts "#{number} parameters to run."
        else
          $stderr.puts "one parameter to run"
        end
        exit 1
      end
    end

    #########################################################################
    # Functions for printing
    #########################################################################

    # Sets bold font
    def scr_bold
      print "\33[1m"
    end

    # Sets underline
    def scr_underline
      print "\33[4m"
    end

    # Restore normal font
    def scr_restore
      print "\33[0m"
    end

    # Clears screen
    def scr_cls
      print "\33[2J\33[H"
    end

    # Moves the cursor
    def scr_move(x,y)
      print "\33[#{x};#{y}H"
    end

    # Class to print tables
    class ShowTable
      attr_accessor :ext, :columns

      # table => definition of the table to print
      # ext => external variables (Hash), @ext
      def initialize(table, ext=nil)
        @table=table
        @ext=Hash.new
        @ext=ext if ext.kind_of?(Hash)
        @columns=@table[:default]
      end

      # Returns a formated string for header
      def header_str
        @columns.collect {|c|
          if @table[c]
            #{}"%#{@table[c][:size]}s" % [@table[c][:name]]
            format_data(c, @table[c][:name])
          else
            nil
          end
        }.compact.join(' ')
      end

      def data_str(data, options=nil)
        # TODO: Use data_array so it can be ordered and/or filtered
        res_data=data_array(data, options)

        res_data.collect {|d|
          (0..(@columns.length-1)).collect {|c|
            dat=d[c]
            col=@columns[c]

            dat = humanize_size( Float(dat) ) if( @table[col][:kbytes] )

            format_data(col, dat) if @table[col]
          }.join(' ')
        }.join("\n")
      end

      def data_array(data, options=nil)
        res_data=data.collect {|d|
          @columns.collect {|c|
            @table[c][:proc].call(d, @ext).to_s if @table[c]
          }
        }

        if options
          filter_data!(res_data, options[:filter]) if options[:filter]
          sort_data!(res_data, options[:order]) if options[:order]
        end

        res_data
      end

      def format_data(field, data)
        minus=( @table[field][:left] ? "-" : "" )
        size=@table[field][:size]
        "%#{minus}#{size}.#{size}s" % [ data.to_s ]
      end

      def get_order_column(column)
        desc=column.match(/^-/)
        col_name=column.gsub(/^-/, '')
        index=@columns.index(col_name.to_sym)
        [index, desc]
      end

      def sort_data!(data, order)
        data.sort! {|a,b|
          # rows are equal by default
          res=0
          order.each {|o|
            # compare
            pos, dec=get_order_column(o)
            break if !pos

            r = (b[pos]<=>a[pos])

            # if diferent set res (return value) and exit loop
            if r!=0
              # change sign if the order is decreasing
              r=-r if dec
              res=r
              break
            end
          }
          res
        }
      end

      def filter_data!(data, filters)
        filters.each {|key, value|
          pos=@columns.index(key.downcase.to_sym)
          if pos
            data.reject! {|d|
              if !d[pos]
                true
              else
                !d[pos].downcase.match(value.downcase)
              end
            }
          end
        }
      end

      def humanize_size(value)
        binarySufix = ["K", "M", "G", "T" ]
        i=0

        while value > 1024 && i < 3 do
          value /= 1024.0
          i+=1
        end

        value = (value * 10).round / 10.0

        value = value.to_i if value - value.round == 0
        st = value.to_s + binarySufix[i]

        return st
      end
    end

    def print_header(format_str, str, underline)
      scr_bold
      scr_underline if underline
      print format_str % str
      scr_restore
      puts
    end

    def print_xml_in_table(list_columns, xml, show_id=false)
      unless show_id
        # remove :id from list_columns
        list_columns.delete(:id)
        list_columns[:default].delete(:id)
      end

      table = ShowTable.new(list_columns)

      scr_bold
      scr_underline
      print table.header_str
      scr_restore
      puts

      puts table.data_str(xml)
    end

    #########################################################################
    # Functions for asking resource ids
    #########################################################################

    # It gets id of a resource stored in RENKEI-VPE.
    # +name+        name of resource
    # +pool_class+  class of resource type
    # [return]      id of the resource
    def get_resource_id(name, pool_class)
      return name.to_i if name.match(/^[0123456789]+$/)

      pool = pool_class.new(RenkeiVPE::Client.new)
      result = pool.ask_id(name)
      if RenkeiVPE.is_error?(result)
        $stderr.puts 'Error: ' + result.message
        exit 1
      end

      pool.asked_id
    end

    # It gets id of a resource in a zone stored in RENKEI-VPE.
    # +name+        name of resource
    # +zone_name+   name of target zone
    # +search_str+  string used for search the resource
    # [return]      id of the resource
    def get_resource_id_from_zone(name, zone_name, search_str)
      pool = RenkeiVPE::ZonePool.new(RenkeiVPE::Client.new)
      result = pool.info
      if RenkeiVPE.is_error?(result)
        $stderr.puts 'Error: ' + result.message
        exit 1
      end

      if zone_name.match(/^[0123456789]+$/)
        zones = pool.select { |z| z.id == zone_name.to_i }
      else
        zones = pool.select { |z| z.name == zone_name }
      end

      if zones.size == 1
        zone = zones[0]
        zone.each(search_str) do |h|
          return h['ID'] if h['NAME'] == name
        end
        $stderr.puts "Error: Host[#{name}] is not found in Zone[#{zone_name}]."
        exit 1
      elsif zones.size > 1
        $stderr.puts "Error: There are multiple zone's with name #{zone_name}."
        exit 1
      else
        $stderr.puts "Error: Zone[#{zone_name}] is not found."
        exit 1
      end
    end

    # It gets ids of resources in a zone stored in RENKEI-VPE.
    # +zone_name+   name of target zone
    # +search_str+  string used for search the resources
    # [return]      array of ids of the resources
    def get_resource_ids_from_zone(zone_name, search_str)
      pool = RenkeiVPE::ZonePool.new(RenkeiVPE::Client.new)
      result = pool.info
      if RenkeiVPE.is_error?(result)
        $stderr.puts 'Error: ' + result.message
        exit 1
      end

      if zone_name.match(/^[0123456789]+$/)
        zones = pool.select { |z| z.id == zone_name.to_i }
      else
        zones = pool.select { |z| z.name == zone_name }
      end

      if zones.size == 1
        zone = zones[0]
        results = []
        zone.each(search_str) do |h|
          results << h['ID']
        end
        return results
      elsif zones.size > 1
        $stderr.puts "Error: There are multiple zone's with name #{zone_name}."
        exit 1
      else
        $stderr.puts "Error: Zone[#{zone_name}] is not found."
        exit 1
      end
    end

    def get_user_id(name)
      get_resource_id(name, RenkeiVPE::UserPool)
    end

    def get_image_id(name)
      get_resource_id(name, RenkeiVPE::ImagePool)
    end

    def get_vm_id(name)
      get_resource_id(name, RenkeiVPE::VirtualMachinePool)
    end

    def get_vmtype_id(name)
      get_resource_id(name, RenkeiVPE::VMTypePool)
    end

    def get_zone_id(name)
      get_resource_id(name, RenkeiVPE::ZonePool)
    end

    def get_lease_id(name)
      get_resource_id(name, RenkeiVPE::LeasePool)
    end

    def get_host_id(name, zone_name)
      get_resource_id_from_zone(name, zone_name, 'HOSTS/HOST')
    end

    def get_host_ids(zone_name)
      get_resource_ids_from_zone(zone_name, 'HOSTS/HOST')
    end

    def get_vn_id(name, zone_name)
      get_resource_id_from_zone(name, zone_name, 'NETWORKS/NETWORK')
    end

    def get_vn_ids(zone_name)
      get_resource_ids_from_zone(zone_name, 'NETWORKS/NETWORK')
    end
  end
end


# Local Variables:
# mode: Ruby
# coding: utf-8
# indent-tabs-mode: nil
# End:
