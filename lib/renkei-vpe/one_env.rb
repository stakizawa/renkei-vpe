##############################################################################
# Environment Configuration
##############################################################################
one_location = ENV["ONE_LOCATION"]

if !one_location
  ruby_lib_location = "/usr/lib/one/ruby"
else
  ruby_lib_location = one_location + "/lib/ruby"
end

$: << ruby_lib_location

