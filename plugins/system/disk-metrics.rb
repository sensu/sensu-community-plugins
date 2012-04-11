#!/usr/bin/env ruby

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'socket'

class DiskGraphite < Sensu::Plugin::Metric::CLI::Graphite

  option :scheme,
    :description => "Metric naming scheme, text to prepend to metric",
    :short => "-s SCHEME",
    :long => "--scheme SCHEME",
    :default => "#{Socket.gethostname}.disk"

  def run
    # http://www.kernel.org/doc/Documentation/iostats.txt
    metrics = [
      'reads', 'readsMerged', 'sectorsRead', 'readTime',
      'writes', 'writesMerged', 'sectorsWritten', 'writeTime',
      'ioInProgress', 'ioTime', 'ioTimeWeighted'
    ]

    File.open("/proc/diskstats", "r").each_line do |line|
      stats = line.strip.split(/\s+/)
      major, minor, dev = stats.shift(3)
      next if stats == ['0'].cycle.take(stats.size)

      metrics.size.times { |i| output "#{config[:scheme]}.#{dev}.#{metrics[i]}", stats[i] }
    end

    ok
  end

end
