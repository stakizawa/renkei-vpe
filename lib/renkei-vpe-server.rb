##############################################################################
# Environment Configuration
##############################################################################
one_location = ENV['ONE_LOCATION']

if !one_location
  ruby_lib_location = '/usr/lib/one/ruby'
else
  ruby_lib_location = one_location + '/lib/ruby'
end

$: << ruby_lib_location

##############################################################################
# Load libraries
##############################################################################
require 'xmlrpc/server'
require 'renkei-vpe-server/image'
require 'renkei-vpe-server/image_pool'

##############################################################################
# Implement XML RPC interface
##############################################################################
module RenkeiVPEServer
  class Image
    INTERFACE = XMLRPC::interface('rvpe.image') do
      meth('val info(string, int)',
           'Retrieve information about the image',
           'info')
      meth('val allocate(string, string)',
           'Allocates a new image in OpenNebula',
           'allocate')
      meth('val delete(string, int)',
           'Deletes an image from the image pool',
           'delete')
      meth('val enable(string, int, bool)',
           'Enables or disables an image',
           'enable')
      meth('val publish(string, int, bool)',
           'Publishes or unpublishes an image',
           'publish')
    end
  end

  class ImagePool
    INTERFACE = XMLRPC::interface('rvpe.imagepool') do
      meth('bool_string info(string, int)',
           'Retrieve information about image pool',
           'info')
    end
  end
end
