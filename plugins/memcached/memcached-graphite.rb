#! /usr/bin/env ruby
#
#   memcached-graphite
#
# DESCRIPTION:
#   Push Memcached stats into graphite
#
# OUTPUT:
#   metric data
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: memcached
#   gem: socket
#
# USAGE:
#   #YELLOW
#
# NOTES:
#   #YELLOW
#   HitRatio percent and per second calculations
#
# LICENSE:
#   Copyright 2012 Pete Shima <me@peteshima.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'memcached'
require 'socket'

class MemcachedGraphite < Sensu::Plugin::Metric::CLI::Graphite
  option :host,
         short: '-h HOST',
         long: '--host HOST',
         description: 'Memcached Host to connect to',
         default: 'localhost'

  option :port,
         short: '-p PORT',
         long: '--port PORT',
         description: 'Memcached Port to connect to',
         proc: proc(&:to_i),
         default: 11_211

  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         default: "#{::Socket.gethostname}.memcached"

  def run
    cache = Memcached.new("#{config[:host]}:#{config[:port]}")

    cache.stats.each do |k, v|
      output "#{config[:scheme]}.#{k}", v
    end

    ok
  end
end
