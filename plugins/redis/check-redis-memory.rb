#!/usr/bin/env ruby
#
# Checks Redis INFO stats and limits values
# ===
#
# Copyright (c) 2012, Panagiotis Papadomitsos <pj@ezgr.net>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'redis'

class RedisChecks < Sensu::Plugin::Check::CLI

  option :host,
    :short => "-h HOST",
    :long => "--host HOST",
    :description => "Redis Host to connect to",
    :required => false,
    :default => '127.0.0.1'

  option :port,
    :short => "-p PORT",
    :long => "--port PORT",
    :description => "Redis Port to connect to",
    :proc => proc {|p| p.to_i },
    :required => false,
    :default => 6379

  option :warn_mem,
    :short => "-w KB",
    :long => "--warnmem KB",
    :description => "Allocated KB of Redis memory on which we'll issue a WARNING",
    :proc => proc {|p| p.to_i },
    :required => true

  option :crit_mem,
    :short => "-c KB",
    :long => "--critmem KB",
    :description => "Allocated BB of memory on which we'll issue a CRITICAL",
    :proc => proc {|p| p.to_i },
    :required => true

  def run
    begin
        redis = Redis.new(:host => config[:host], :port =>config[:port])

        used_memory = redis.info.fetch('used_memory').to_i.div(1024)
        warn_memory = config[:warn_mem]
        crit_memory = config[:crit_mem]
        if (used_memory >= crit_memory)    
            critical "Redis running on #{config[:host]}:#{config[:port]} is above the CRITICAL limit: #{used_memory} KB used / #{crit_memory} KB limit"  
        elsif (used_memory >= warn_memory)
            warning "Redis running on #{config[:host]}:#{config[:port]} is above the WARNING limit: #{used_memory} KB used / #{warn_memory} KB limit"
        else
            ok 'Redis memory usage is below defined limits'
        end
    rescue
        warning "Could not connect to Redis server on #{config[:host]}:#{config[:port]}"
    end
  end

end
