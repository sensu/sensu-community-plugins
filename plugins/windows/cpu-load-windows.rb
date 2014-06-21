#!/usr/bin/env ruby
#
# This is metrics which outputs the CPU load in Graphite acceptable format.
# To get the cpu stats for Windows Server to send over to Graphite.
# It basically uses the typeperf to get the processor usage at a given particular time.
#
# Copyright 2013 <jashishtech@gmail.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.
# rubocop:disable VariableName, MethodName

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'socket'

class CpuMetric < Sensu::Plugin::Metric::CLI::Graphite

  option :scheme,
    :description => "Metric naming scheme, text to prepend to .$parent.$child",
    :long => "--scheme SCHEME",
    :default => "#{Socket.gethostname}"

  def getcpuLoad
    tempArr=[]
    timestamp = Time.now.utc.to_i
    io= IO.popen("typeperf -sc 1 \"processor(_total)\\% processor time\" ") # { |io|
    tempArr.push(line) while (line = io.gets) # rubocop:disable UselessAssignment
    temp = tempArr[2].split(",")[1]
    cpuMetric = temp[1, temp.length - 3].to_f
    [cpuMetric, timestamp]
  end

  def run
    values = getcpuLoad
    metrics = {
        :cpu => {
            :loadavgsec => values[0]
        }
    }
    metrics.each do |parent, children|
      children.each do |child, value|
        output [config[:scheme], parent, child].join("."), value, values[1]
      end
    end
    ok
  end
end
