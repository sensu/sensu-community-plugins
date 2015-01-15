#! /usr/bin/env ruby
#
#   windows-cpu-load-metrics
#
# DESCRIPTION:
#   This is metrics which outputs the CPU load in Graphite acceptable format.
#   To get the cpu stats for Windows Server to send over to Graphite.
#   It basically uses the typeperf to get the processor usage at a given particular time.
#
# OUTPUT:
#   metric data
#
# PLATFORMS:
#   Windows
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
#   Copyright 2013 <jashishtech@gmail.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'socket'

class CpuMetric < Sensu::Plugin::Metric::CLI::Graphite
  option :scheme,
         description: 'Metric naming scheme, text to prepend to .$parent.$child',
         long: '--scheme SCHEME',
         default: "#{Socket.gethostname}"

  def acquire_cpu_load
    temp_arr = []
    timestamp = Time.now.utc.to_i
    IO.popen("typeperf -sc 1 \"processor(_total)\\% processor time\" ") { |io| io.each { |line| temp_arr.push(line) } }
    temp = temp_arr[2].split(',')[1]
    cpu_metric = temp[1, temp.length - 3].to_f
    [cpu_metric, timestamp]
  end

  def run
    values = acquire_cpu_load
    metrics = {
      cpu: {
        loadavgsec: values[0]
      }
    }
    metrics.each do |parent, children|
      children.each do |child, value|
        output [config[:scheme], parent, child].join('.'), value, values[1]
      end
    end
    ok
  end
end
