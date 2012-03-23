#!/usr/bin/env ruby
#
# Push Memcached stats into graphite
# ===
#
# TODO: HitRatio percent and per second calculations
#
# Copyright 2012 Pete Shima <me@peteshima.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'memcached'

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

  option :scheme,
    :description => "Metric naming scheme, text to prepend to metric",
    :short => "-s SCHEME",
    :long => "--scheme SCHEME",
    :default => "#{Socket.gethostname}.redis"

  def run
    cache = Memcached.new("#{config[:host]}:#{config[:port]}")

    cache.stats.each do |k, v|
      output "#{config[:scheme]}.#{k}", v
    end

    ok
  end

end
