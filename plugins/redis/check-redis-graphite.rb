#!/usr/bin/env ruby
#
# ==================================================================
# => Redis stats into graphite
# ==================================================================
#
#  By Pete Shima - https://github.com/petey5king
#
# ==================================================================
#  Requirements
# ==================================================================
#  * redis gem
#  * graphite handler already setup
#  * firewall ports opened (if needed)
#  
# ==================================================================
#  Example sensu config:
# ==================================================================
#
# "checks": {
#       "redis_graphite_staging": {
#         "handlers": [
#           "graphite"
#         ],
#         "command": "/path/to/check-redis-graphite.rb -h my.hostname.com -p 6379",
#         "subscribers": [
#           "sensu_server"
#         ],
#         "type": "metric",
#         "interval": 60
#       },
#
# ==================================================================
#  TODO
# ==================================================================
#  * Only pass integer based or needed metrics rather than all
#


require "rubygems" if RUBY_VERSION < "1.9.0"
require 'sensu-plugin/metric/cli'
require "redis"

class Redis2Graphite < Sensu::Plugin::Metric::CLI::Graphite

  option :host,
  :short => "-h HOST",
  :long => "--host HOST",
  :description => "Redis Host to connect to",
  :required => true

  option :port,
  :short => "-p PORT",
  :long => "--port PORT",
  :description => "Redis Port to connect to",
  :proc => proc {|p| p.to_i },
  :required => true


  def run
    gstring = "servers." + config[:host].gsub(/.my.hostname.com/, '')  
    
    $cache = Redis.new(:host => config[:host], :port =>config[:port])

    $cache.info.each {|k,v|
      output "#{gstring}.redis.#{k}", v
    }

    ok

  end
end
