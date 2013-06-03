#!/usr/bin/env ruby
#
# Network interface throughput
# ===
#
# DEPENDENCIES:
#   sensu-plugin Ruby gem
#   sysstat to get 'sar'
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'socket'

class NetIFMetrics < Sensu::Plugin::Metric::CLI::Graphite

  option :scheme,
    :description => "Metric naming scheme, text to prepend to .$parent.$child",
    :long => "--scheme SCHEME",
    :default => "#{Socket.gethostname}"

  def run
    `sar -n DEV 1 1 | grep Average | grep -v IFACE`.each_line do |line|
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
