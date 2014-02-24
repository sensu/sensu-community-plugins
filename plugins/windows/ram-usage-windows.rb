#!/usr/bin/env ruby
#
#
# This is metrics which outputs the Ram usage in Graphite acceptable format.
# To get the cpu stats for Windows Server to send over to Graphite.
# It basically uses the typeperf(To get available memory) and wmic(Used to get the usable memory size)
# to get the processor usage at a given particular time.
#
# Copyright 2013 <jashishtech@gmail.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.
# rubocop:disable VariableName, MethodName

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'socket'

class RamMetric < Sensu::Plugin::Metric::CLI::Graphite

  option :scheme,
    :description => "Metric naming scheme, text to prepend to .$parent.$child",
    :long => "--scheme SCHEME",
    :default => "#{Socket.gethostname}"

  def getRamUsage
    tempArr1=[]
    tempArr2=[]
    result1 = IO.popen("typeperf -sc 1 \"Memory\\Available bytes\" ")
    tempArr1.push(line) while (line = result1.gets) # rubocop:disable UselessAssignment
    temp = tempArr1[2].split(",")[1]
    ramAvailableInBytes = temp[1, temp.length - 3].to_f
    timestamp = Time.now.utc.to_i
    result2 = IO.popen("wmic OS get TotalVisibleMemorySize /Value")
    tempArr2.push(line) while (line=result2.gets)
    totalRam = tempArr2[4].split('=')[1].to_f
    totalRamInBytes = totalRam*1000.0
    ramUsePercent=(totalRamInBytes - ramAvailableInBytes)*100.0/(totalRamInBytes)
    [ramUsePercent.round(2), timestamp]
  end

  def run
    # To get the ram usage
    values = getRamUsage
    metrics = {
        :ram => {
            :ramUsagePersec => values[0]
        }
    }
    metrics.each do|parent, children|
      children.each do|child, value|
        output [config[:scheme], parent, child].join("."), value, values[1]
      end
    end
    ok
  end
end
