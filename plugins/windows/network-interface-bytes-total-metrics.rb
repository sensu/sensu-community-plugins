#!/usr/bin/env ruby
#
# Check Network Interface Bytes Total/sec Metric
# ===
#
# Tested on Windows 2012RC2.
#
# Yohei Kawahara <inokara@gmail.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'socket'

class NetworkInterfaceBytesTotal < Sensu::Plugin::Metric::CLI::Graphite

  option :scheme,
    :description => "Metric naming scheme, text to prepend to .$parent.$child",
    :long => "--scheme SCHEME",
    :default => "#{Socket.gethostname}.network_interface_bytes_total"

  option :interface,
    :short => '-i interface',
    :default => "AWS PV Network Device _0"

  def run
    io = IO.popen("typeperf -sc 1 \"Network\ Interface(#{config[:interface]})\\Bytes\ Total\/sec\"")
    nw_if_bt = io.readlines[2].split(',')[1].gsub(/"/, '').to_f
    interface = config[:interface].gsub(/ /, "_")
    output [config[:scheme], "#{interface}"].join('.'), nw_if_bt
  end
end
