#!/usr/bin/env ruby

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'socket'

class InterfaceGraphite < Sensu::Plugin::Metric::CLI::Graphite

  option :scheme,
    :description => "Metric naming scheme, text to prepend to metric",
    :short => "-s SCHEME",
    :long => "--scheme SCHEME",
    :default => "#{Socket.gethostname}.interface"

  def run
    # Metrics borrowed from hoardd: https://github.com/coredump/hoardd

    metrics = [
      'rxBytes', 'rxPackets', 'rxErrors', 'rxDrops',
      'rxFifo', 'rxFrame', 'rxCompressed', 'rxMulticast',
      'txBytes', 'txPackets', 'txErrors', 'txDrops',
      'txFifo', 'txColls', 'txCarrier', 'txCompressed'
    ]

    File.open("/proc/net/dev", "r").each_line do |line|
      interface, stats_string = line.scan(/^\s*([^:]+):\s*(.*)$/).first
      next unless interface

      stats = stats_string.split(/\s+/)
      next if stats == ['0'].cycle.take(stats.size)

      metrics.size.times { |i| output "#{config[:scheme]}.#{interface}.#{metrics[i]}", stats[i] }
    end

    ok
  end

end
