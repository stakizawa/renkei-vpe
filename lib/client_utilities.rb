#####################
# CONSOLE UTILITIES #
#####################

BinarySufix = ["K", "M", "G", "T" ]

def humanize_size(value)
  i=0

  while value > 1024 && i < 3 do
    value /= 1024.0
    i+=1
  end

  value = (value * 10).round / 10.0

  value = value.to_i if value - value.round == 0
  st = value.to_s + BinarySufix[i]

  return st
end

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

# Print header
def print_header(format_str, str, underline)
  scr_bold
  scr_underline if underline
  print format_str % str
  scr_restore
  puts
end

##################################
# Class show configurable tables #
##################################

ShowTableExample={
  :id => {
    :name => "ID",
    :size => 4,
    :proc => lambda {|d,e| d["OID"] }
  },
  :name => {
    :name => "NAME",
    :size => 8,
    :proc => lambda {|d,e| d["DEPLOY_ID"] }
  },
  :stat => {
    :name => "STAT",
    :size => 4,
    :proc => lambda {|d,e| e[:vm].get_state(d) }
  },
  :default => [:id, :name, :stat]
}

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

  # Returns an array with header titles
  def header_array
    @columns.collect {|c|
      if @table[c]
        @table[c][:name].to_s
      else
        ""
      end
    }.compact
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

    #data.collect {|d|
    #    @columns.collect {|c|
    #        format_data(c, @table[c][:proc].call(d, @ext)) if @table[c]
    #    }.join(' ')
    #}.join("\n")
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

  def print_help
    text=[]
    @table.each {|option, data|
      next if option==:default
      text << "%9s (%2d) => %s" % [option, data[:size], data[:desc]]
    }
    text.join("\n")
  end

end

def print_xml_friendly(list_columns, xml, show_id=false)
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



################
# Miscelaneous #
################

def get_rvpe_client(session=nil)
  RenkeiVPE::Client.new(session)
end

def is_error?(result)
  RenkeiVPE.is_error?(result)
end

def is_successful?(result)
  !RenkeiVPE.is_error?(result)
end

def is_integer?(obj)
  return true if obj.kind_of?(Integer)
  if obj.instance_of?(String)
    return true if /^-?[0123456789]+$/ =~ obj
  end
  return false
end

def check_parameters(name, number)
  if ARGV.length < number
    print "Command #{name} requires "
    if number>1
      puts "#{number} parameters to run."
    else
      puts "one parameter to run"
    end
    exit -1
  end
end


def get_entity_id(name, pool_class)
  return name.to_i if name.match(/^[0123456789]+$/)

  pool = pool_class.new(get_rvpe_client)
  result = pool.ask_id(name)
  if RenkeiVPE.is_error?(result)
    puts result.message
    exit -1
  end

  pool.asked_id
end

def get_entity_id_from_zone(name, zone_name, search_str)
  pool = RenkeiVPE::ZonePool.new(get_rvpe_client)
  result = pool.info
  if RenkeiVPE.is_error?(result)
    puts result.message
    exit -1
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
  elsif zones.size > 1
    puts "There are multiple zone's with name #{zone_name}."
    exit -1
  else
    puts "Zone[#{zone_name}] not found."
    exit -1
  end
end

def get_entity_ids_from_zone(zone_name, search_str)
  pool = RenkeiVPE::ZonePool.new(get_rvpe_client)
  result = pool.info
  if RenkeiVPE.is_error?(result)
    puts result.message
    exit -1
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
    puts "There are multiple zone's with name #{zone_name}."
    exit -1
  else
    puts "Zone[#{zone_name}] not found."
    exit -1
  end
end

def get_vm_id(name)
  get_entity_id(name, RenkeiVPE::VirtualMachinePool)
end

def get_vmtype_id(name)
  get_entity_id(name, RenkeiVPE::VMTypePool)
end

def get_lease_id(name)
  get_entity_id(name, RenkeiVPE::LeasePool)
end

def get_host_id(name, zone_name)
  get_entity_id_from_zone(name, zone_name, 'HOSTS/HOST')
end

def get_host_ids(zone_name)
  get_entity_ids_from_zone(zone_name, 'HOSTS/HOST')
end

def get_vn_id(name, zone_name)
  get_entity_id_from_zone(name, zone_name, 'NETWORKS/NETWORK')
end

def get_vn_ids(zone_name)
  get_entity_ids_from_zone(zone_name, 'NETWORKS/NETWORK')
end

def get_user_id(name)
  get_entity_id(name, RenkeiVPE::UserPool)
end

def get_image_id(name)
  get_entity_id(name, RenkeiVPE::ImagePool)
end

def get_zone_id(name)
  get_entity_id(name, RenkeiVPE::ZonePool)
end

def str_running_time(data)
  stime=Time.at(data["STIME"].to_i)
  if data["ETIME"]=="0"
    etime=Time.now
  else
    etime=Time.at(data["ETIME"].to_i)
  end
  dtime=Time.at(etime-stime).getgm

  "%02d %02d:%02d:%02d" % [dtime.yday-1, dtime.hour, dtime.min, dtime.sec]
end

def str_register_time(data)
  regtime=Time.at(data["REGTIME"].to_i).getgm
  regtime.strftime("%b %d, %Y %H:%M")
end


REG_RANGE=/(.*)\[(\d+)([+-])(\d+)\](.*)/

def expand_range(param)
  if match=param.match(REG_RANGE)
    pre=match[1]
    start=match[2]
    operator=match[3]
    last=match[4]
    post=match[5]
    size=0

    result=Array.new

    if operator=='-'
      range=(start.to_i..last.to_i)
      size=last.size
    elsif operator=='+'
      size=(start.to_i+last.to_i-1).to_s.size
      range=(start.to_i..(start.to_i+last.to_i-1))
    end

    if start[0]==?0
      range.each do |num|
        result<<sprintf("%s%0#{size}d%s", pre, num, post)
      end
    else
      range.each do |num|
        result<<sprintf("%s%d%s", pre, num, post)
      end
    end

    result
  else
    param
  end
end

def expand_args(args)
  args.collect {|arg| expand_range(arg) }.flatten
end


### Local variables:
### mode: Ruby
### coding: utf-8-unix
### indent-tabs-mode: nil
### End:
