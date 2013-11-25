#!/usr/bin/env ruby
#
# This is a drop-in replacement for the graphite mutator written
# as a Sensu Extention for better performance.
#
# It transforms parameter name if it's a hostname.
#
# There are two transforms you can apply separately:
#    * Replace dots in FQDN to user specified strings.
#      e.g. foo.example.com -> foo_example_com
#    * Output the hostname in reverse order.
#      e.g. foo.example.com -> com.example.foo
#
# The default configuration is:
#
#    {
#      "graphite": {
#        "reverse": false,
#        "replace": "_"
#      }
#    }
#
# Copyright 2013 Mitsutoshi Aoe <maoe@foldr.in>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

module Sensu::Extension
  class Graphite < Mutator
    def name
      'graphite'
    end

    def description
      'OnlyCheckOutput mutator for Graphite'
    end

    def post_init
      @reverse = false
      @replace = '_'

      if settings['graphite']
        if settings['graphite']['reverse'] == true
          @reverse = true
        end
        if settings['graphite']['replace']
          @replace = settings['graphite']['replace']
        end
      end
    end

    def run(event, &block)
      client_name = event[:client][:name]
      if @reverse
        renamed_client_name = client_name.split('.').reverse.join('.')
      else
        renamed_client_name = client_name
      end
      renamed_client_name = renamed_client_name.gsub('.', @replace)
      mutated = event[:check][:output].gsub(client_name, renamed_client_name)
      block.call(mutated, 0)
    end
  end
end
