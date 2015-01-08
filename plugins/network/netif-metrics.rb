#! /usr/bin/env ruby
#
#   netif-metrics
#
# DESCRIPTION:
#   Network interface throughput
#
# OUTPUT:
#   metric data
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: socket
#
# USAGE:
#   #YELLOW
#
# NOTES:
#
# LICENSE:
#   Copyright 2014 Sonian, Inc. and contributors. <support@sensuapp.org>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'socket'

class NetIFMetrics < Sensu::Plugin::Metric::CLI::Graphite
  option :scheme,
         description: 'Metric naming scheme, text to prepend to .$parent.$child',
         long: '--scheme SCHEME',
         default: "#{Socket.gethostname}"

  def run
    # #YELLOW
    `sar -n DEV 1 1 | grep Average | grep -v IFACE`.each_line do |line|  # rubocop:disable Style/Next
      stats = line.split(/\s+/)
      unless stats.empty?
        stats.shift
        nic = stats.shift
        output "#{config[:scheme]}.#{nic}.rx_kB_per_sec", stats[2].to_f if stats[3]
        output "#{config[:scheme]}.#{nic}.tx_kB_per_sec", stats[3].to_f if stats[3]
      end
    end

    ok
  end
end
