#!/usr/bin/env ruby
#
# ==================================================================
# => Memcached stats into graphite
# ==================================================================
#
#  By Pete Shima - https://github.com/petey5king
#
#  Inspiration: https://github.com/sonian/sensu-community-plugins/
#      blob/master/plugins/memcached/check-memcached-stats.rb
#
# ==================================================================
#  Requirements
# ==================================================================
#  * memcached gem
#  * graphite handler already setup
#  * firewall ports opened
#  
# ==================================================================
#  Example sensu config:
# ==================================================================
#
# "checks": {
#       "memcached_graphite_staging": {
#         "handlers": [
#           "graphite"
#         ],
#         "command": "/path/to/check-memcached-graphite.rb -h my.hostname.com -p 11211",
#         "subscribers": [
#           "sensu_server"
#         ],
#         "type": "metric",
#         "interval": 60
#       },
#


require "rubygems" if RUBY_VERSION < "1.9.0"
require 'sensu-plugin/metric/cli'
require "memcached"

class MemcachedGraphite < Sensu::Plugin::Metric::CLI::Graphite

  option :host,
  :short => "-h HOST",
  :long => "--host HOST",
  :description => "Memcached Host to connect to",
  :required => true

  option :port,
  :short => "-p PORT",
  :long => "--port PORT",
  :description => "Memcached Port to connect to",
  :proc => proc {|p| p.to_i },
  :required => true

  def run
    #one liner to update the graphite path to your liking.
    gstring = "servers." + config[:host].gsub(/.my.hostname.com/, '')  
    
    $cache = Memcached.new("#{config[:host]}:#{config[:port]}")

    #this updates all the configs - not all needed, and would be nice
    # to get the hit ratio as well.
    $cache.stats.each {|k,v|
      output "#{gstring}.memcached.#{k}", v
    }

    ok

  end
end
