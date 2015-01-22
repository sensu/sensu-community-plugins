#! /usr/bin/env ruby
#
#   ram-usage-windows
#
# DESCRIPTION:
#   This is metrics which outputs the Ram usage in Graphite acceptable format.
#   To get the cpu stats for Windows Server to send over to Graphite.
#   It basically uses the typeperf(To get available memory) and wmic(Used to get the usable memory size)
#   to get the processor usage at a given particular time.
#
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

class RamMetric < Sensu::Plugin::Metric::CLI::Graphite
  option :scheme,
         description: 'Metric naming scheme, text to prepend to .$parent.$child',
         long: '--scheme SCHEME',
         default: "#{Socket.gethostname}"

  def acquire_ram_usage
    temp_arr_1 = []
    temp_arr_2 = []
    timestamp = Time.now.utc.to_i
    IO.popen("typeperf -sc 1 \"Memory\\Available bytes\" ") { |io| io.each { |line| temp_arr_1.push(line) } }
    temp = temp_arr_1[2].split(',')[1]
    ram_available_in_bytes = temp[1, temp.length - 3].to_f
    IO.popen('wmic OS get TotalVisibleMemorySize /Value') { |io| io.each { |line| temp_arr_2.push(line) } }
    total_ram = temp_arr_2[4].split('=')[1].to_f
    total_ram_in_bytes = total_ram * 1000.0
    ram_use_percent = (total_ram_in_bytes - ram_available_in_bytes) * 100.0 / (total_ram_in_bytes)
    [ram_use_percent.round(2), timestamp]
  end

  def run
    # To get the ram usage
    values = acquire_ram_usage
    metrics = {
      ram: {
        ramUsagePersec: values[0]
      }
    }
    metrics.each do|parent, children|
      children.each do|child, value|
        output [config[:scheme], parent, child].join('.'), value, values[1]
      end
    end
    ok
  end
end
