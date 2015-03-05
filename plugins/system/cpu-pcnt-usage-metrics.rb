#! /usr/bin/env ruby
#  encoding: UTF-8
#
#   cpu-pct-usage-metrics
#
# DESCRIPTION:
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
#
# NOTES:
#
# LICENSE:
#   Copyright 2012 Sonian, Inc <chefs@sonian.net>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#
require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'socket'

class CpuGraphite < Sensu::Plugin::Metric::CLI::Graphite
  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         default: "#{Socket.gethostname}.cpu"

  def acquire_proc_stats
    cpu_metrics = %w(user nice system idle iowait irq softirq steal guest)
    File.open('/proc/stat', 'r').each_line do |line|
      info = line.split(/\s+/)
      next if info.empty?
      name = info.shift

      # we are matching TOTAL stats and returning a hash of values
      if name.match(/^cpu$/)
        # return the CPU metrics sample as a hash
        # filter out nil values, as some kernels don't have a 'guest' value
        return Hash[cpu_metrics.zip(info.map(&:to_i))].reject { |_key, value| value.nil? }
      end
    end
  end

  def sum_cpu_metrics(metrics)
    # #YELLOW
    metrics.values.reduce { |sum, metric| sum + metric } # rubocop:disable SingleLineBlockParams
  end

  def run
    cpu_sample1 = acquire_proc_stats
    sleep(1)
    cpu_sample2 = acquire_proc_stats
    cpu_metrics = cpu_sample2.keys

    # we will sum all jiffy counts read in acquire_proc_stats
    cpu_total1 = sum_cpu_metrics(cpu_sample1)
    cpu_total2 = sum_cpu_metrics(cpu_sample2)
    # total cpu usage in last second in CPU jiffs (1/100 s)
    cpu_total_diff  = cpu_total2 - cpu_total1
    # per CPU metric diff
    cpu_sample_diff = Hash[cpu_sample2.map { |k, v| [k, v - cpu_sample1[k]] }]

    cpu_metrics.each do |metric|
      metric_val = sprintf('%.02f', (cpu_sample_diff[metric] / cpu_total_diff.to_f) * 100)
      output "#{config[:scheme]}.#{metric}", metric_val
    end
    ok
  end
end
