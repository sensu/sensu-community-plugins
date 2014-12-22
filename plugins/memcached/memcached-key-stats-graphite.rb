#! /usr/bin/env ruby
#
#   memcached-key-stats-graphite
#
# DESCRIPTION:
#   Get memcached per key detailed get, set, and del operation metrics
#
# OUTPUT:
#   metric data
#
# PLATFORMS:
#   Linux, Windows, BSD, Solaris, etc
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: <?>
#
# USAGE:
#   #YELLOW
#
# NOTES:
#
# LICENSE:
#   Copyright 2013 Piavlo <lolitushka@gmail.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'socket'
require 'timeout'

class MemcachedKeyStatsGraphite < Sensu::Plugin::Metric::CLI::Graphite
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

  option :timeout,
         description: 'Timeout in seconds to complete the operation',
         short: '-t SECONDS',
         long: '--timeout SECONDS',
         proc: proc(&:to_i),
         default: 5

  def run
    Timeout.timeout(config[:timeout]) do
      TCPSocket.open("#{config[:host]}", "#{config[:port]}") do |socket|
        socket.print "stats detail dump\r\n"
        socket.close_write
        recv = socket.read
        # #YELLOW
        recv.each_line do |line| # rubocop:disable Style/Next
          if line.match('PREFIX')
            _, key, _, get, _, hit, _, set, _, del = line.split(' ', -1)
            output "#{config[:scheme]}.#{key}.get", get.to_i
            output "#{config[:scheme]}.#{key}.hit", hit.to_i
            output "#{config[:scheme]}.#{key}.set", set.to_i
            output "#{config[:scheme]}.#{key}.del", del.to_i
          end
        end
      end
    end
    ok
  rescue Timeout::Error
    puts "timed out gettings stats from memcached on port #{config[:port]}"
  rescue
    puts "Can't connect to port #{config[:port]}"
    exit(1)
  end
end
