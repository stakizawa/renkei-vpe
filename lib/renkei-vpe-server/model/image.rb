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
    class Image
      # id of the image
      attr_reader :id
      # name of the image
      attr_reader :name

      def initialize(id, name)
        @id   = id
        @name = name
      end

      def self.each(one_session, cond_flag)
        rc = RenkeiVPE::OpenNebulaClient.call_one_xmlrpc('one.imagepool.info',
                                                         one_session,
                                                         cond_flag)
        raise rc[1] unless rc[0]

        doc = REXML::Document.new(rc[1])
        doc.elements.each('IMAGE_POOL/IMAGE') do |e|
          id   = e.elements['ID'].get_text.to_s.to_i
          name = e.elements['NAME'].get_text
          yield Image.new(id, name)
        end
      end

      def self.find_by_name(name, one_session, cond_flag)
        result = []
        Image.each(one_session, cond_flag) do |img|
          result << img if img.name == name
        end
        return result
      end

    end
  end
end


# Local Variables:
# mode: Ruby
# coding: utf-8
# indent-tabs-mode: nil
# End:
