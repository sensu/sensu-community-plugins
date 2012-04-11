#!/usr/bin/env ruby

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'socket'

class CpuGraphite < Sensu::Plugin::Metric::CLI::Graphite

  option :scheme,
    :description => "Metric naming scheme, text to prepend to metric",
    :short => "-s SCHEME",
    :long => "--scheme SCHEME",
    :default => "#{Socket.gethostname}.cpu"

  def run
    cpu_metrics = [ 'user', 'nice', 'system', 'idle', 'iowait', 'irq', 'softirq', 'steal', 'guest' ]
    other_metrics = [ 'ctxt', 'processes', 'procs_running', 'procs_blocked' ]

    File.open("/proc/stat", "r").each_line do |line|
      info = line.split(/\s+/)
      name = info.shift

      if name.match(/cpu([0-9]+|)/)
        name = 'total' if name == 'cpu'
        cpu_metrics.size.times { |i| output "#{config[:scheme]}.#{name}.#{cpu_metrics[i]}", info[i] }
      end

      if other_metrics.include? name
        output "#{config[:scheme]}.#{name}", info.last
      end
    end

    ok
  end

end
