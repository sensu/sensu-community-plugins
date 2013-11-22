#!/usr/bin/env ruby
#
# To get the cpu and ram stats for Windows Server
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'socket'

class CpuRamMetric < Sensu::Plugin::Metric::CLI::Graphite

  option :scheme,
    :description => "Metric naming scheme, text to prepend to .$parent.$child",
    :long => "--scheme SCHEME",
    :default => "#{Socket.gethostname}"

  def getcpuLoad()
	tempArr=[]
	timestamp = Time.now.utc.to_i	
	IO.popen("typeperf -sc 1 \"processor(_total)\\% processor time\" "){			
		|io| while (line = io.gets) do 
			if line != ""
				tempArr.push(line)
			end
		end
	}
	temp = tempArr[2].split(",")[1]
	cpuMetric = temp[1,temp.length - 3].to_f
	return [cpuMetric,timestamp]
  end	

  def run
        #temp = system("wmic cpu get loadpercentage ")
		values = getcpuLoad()
		valuesRam=getRamUsage()
		'''timestamp = Time.now.utc.to_i
		tempArr=[]
		IO.popen("wmic cpu get loadpercentage") { |io| while (line = io.gets) do tempArr.push(line) end }
		tempArr''' 
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



