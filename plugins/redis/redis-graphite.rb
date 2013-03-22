#!/usr/bin/env ruby
#
# Push Redis INFO stats into graphite
# ===
#
# Copyright 2012 Pete Shima <me@peteshima.com>
#                Brian Racer <bracer@gmail.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'redis'

class Redis2Graphite < Sensu::Plugin::Metric::CLI::Graphite

  # redis.c - sds genRedisInfoString(char *section)
  SKIP_KEYS_REGEX = ['gcc_version', 'master_host', 'master_link_status',
                     'master_port', 'mem_allocator', 'multiplexing_api', 'process_id',
                     'redis_git_dirty', 'redis_git_sha1', 'redis_version', '^role',
                     'run_id', '^slave', 'used_memory_human', 'used_memory_peak_human']

  option :host,
    :short => "-h HOST",
    :long => "--host HOST",
    :description => "Redis Host to connect to",
    :default  => '127.0.0.1'

  option :port,
    :short => "-p PORT",
    :long => "--port PORT",
    :description => "Redis Port to connect to",
    :proc => proc {|p| p.to_i },
    :default => 6379

  option :scheme,
    :description => "Metric naming scheme, text to prepend to metric",
    :short => "-s SCHEME",
    :long => "--scheme SCHEME",
    :default => "#{Socket.gethostname}.redis"

  def run
    redis = Redis.new(:host => config[:host], :port => config[:port])

    redis.info.each do |k, v|
      next unless SKIP_KEYS_REGEX.map { |re| k.match(/#{re}/)}.compact.empty?

      # "db0"=>"keys=123,expires=12"
      if k =~ /^db/
        keys, expires = v.split(',')
        keys.gsub!('keys=', '')
        expires.gsub!('expires=', '')

        output "#{config[:scheme]}.#{k}.keys", keys
        output "#{config[:scheme]}.#{k}.expires", expires
      else
        output "#{config[:scheme]}.#{k}", v
      end
    end

    ok
  end
end
