#!/usr/bin/env ruby
#
# Checks checks variables from redis INFO http://redis.io/commands/INFO
#
# ===
#
# Depends on redis gem
# gem install redis
#
# ===
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.
#
# Heavily inspired in check-redis-slave-status.rb
# https://github.com/sensu/sensu-community-plugins/blob/master/plugins/redis/check-redis-slave-status.rb
#
require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'redis'

class RedisSlaveCheck < Sensu::Plugin::Check::CLI

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

  option :redis_info_key,
    :short => "-K VALUE",
    :long => "--redis-info-key KEY",
    :description => "Redis info key to monitor",
    :required => false,
    :default => 'role'

  option :redis_info_value,
    :short => "-V VALUE",
    :long => "--redis-info-key-value VALUE",
    :description => "Redis info key value to trigger alarm",
    :required => false,
    :default => 'master'

  def run
    begin

      options = {:host => config[:host], :port => config[:port]}
      options[:password] = config[:password] if config[:password]
      redis = Redis.new(options)

      if redis.info.fetch("#{config[:redis_info_key]}") == "#{config[:redis_info_value]}"
        ok "Redis #{config[:redis_info_key]} is #{config[:redis_info_value]}"
      else
        critical "Redis #{config[:redis_info_key]} is #{redis.info.fetch("#{config[:redis_info_key]}")}!"
      end

    rescue
      message "Could not connect to Redis server on #{config[:host]}:#{config[:port]}"
      exit 1
    end
  end

end
