#!/usr/bin/env ruby
#
# Checks Redis Slave Replication

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'redis'

class RedisSlaveChecks < Sensu::Plugin::Check::CLI

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
    :proc => proc { |p| p.to_i },
    :required => false,
    :default => 6379

  option :password,
    :short => "-P PASSWORD",
    :long => "--password PASSWORD",
    :description => "Redis Password to connect with"

  option :crit_link_down,
    :short => "-c KB",
    :long => "--critlinkdown SEC",
    :description => "Seconds for the link down to issue CRITICAL",
    :proc => proc { |p| p.to_i },
    :required => true

  option :warn_link_down,
    :short => "-c KB",
    :long => "--warnlinkdown SEC",
    :description => "Seconds for the link down to issue WARN",
    :proc => proc { |p| p.to_i },
    :required => true

  option :crit_left_bytes,
    :short => "-c KB",
    :long => "--critleftbytes BYTES",
    :description => "Bytes to reach to issue CRITICAL on slave sync",
    :proc => proc { |p| p.to_i },
    :required => true

  option :warn_left_bytes,
    :short => "-c KB",
    :long => "--warnleftbytes BYTES",
    :description => "Bytes to reach to issue WARN on slave sync",
    :proc => proc { |p| p.to_i },
    :required => true

  def run
    begin
      options = {:host => config[:host], :port => config[:port]}
      options[:password] = config[:password] if config[:password]
      redis = Redis.new(options)

      master_link_down_seconds = redis.info.fetch('master_link_down_since_seconds').to_i
      master_sync_left_bytes = redis.info.fetch('master_sync_left_bytes')

      crit_master_link_down_seconds = config[:crit_link_down]
      warn_master_link_down_seconds = config[:warn_link_down]
      crit_master_sync_left_bytes = config[:crit_left_bytes]
      warn_master_sync_left_bytes = config[:warn_left_bytes]

      if (master_link_down_seconds >= crit_master_link_down_seconds)
        critical "Redis running on #{config[:host]}:#{config[:port]} is above the CRITICAL limit:\
                  Link has been down for #{master_link_down_seconds} seconds / #{crit_master_link_down_seconds} limit"
      elsif (master_link_down_seconds >= warn_master_link_down_seconds)
        warning "Redis running on #{config[:host]}:#{config[:port]} is above the WARNING limit:\
                 Link has been down for #{master_link_down_seconds} seconds / #{warn_master_link_down_seconds} limit"
      else
        ok 'Redis link down seconds is below defined limits'
      end

      if (master_sync_left_bytes >= crit_master_sync_left_bytes)
        critical "Redis running on #{config[:host]}:#{config[:port]} is above the CRITICAL limit:\
                  Link has been down for #{master_sync_left_bytes} seconds / #{crit_master_sync_left_bytes} limit"
      elsif (master_sync_left_bytes >= warn_master_sync_left_bytes)
        warning "Redis running on #{config[:host]}:#{config[:port]} is above the WARNING limit:\
                  Link has been down for #{master_sync_left_bytes} seconds / #{warn_master_sync_left_bytes} limit"
      else
        ok 'Redis sync left bytes is below defined limits'
      end
      exit 0
    rescue
      message "Could not connect to Redis server on #{config[:host]}:#{config[:port]}"
      exit 1
    end
  end
end
