#!/usr/bin/env ruby
#
# IOStat Extended Metrics Plugin
#
# This plugin collects extended iostat data (iowait -x) for a 
# specified disk or all disks. Output is in Graphite format. 
# See `man iostat` for detailed explaination of each field:
#
#   rrqms,wrqms,rs,ws,rsecs,wsecs,avgrq_sz,
#   avgqu_sz,await,svctm,percent_util
#
# Bethany Erskine <bethany@paperlesspost.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'socket'

class IOStatExtended < Sensu::Plugin::Metric::CLI::Graphite

  option :scheme,
    :description => "Metric naming scheme, text to prepend to .$parent.$child",
    :short => "-s SCHEME",
    :long => "--scheme SCHEME",
    :default => "#{Socket.gethostname}"

  option :disk,
    :description => "Disk to gather stats for",
    :short => "-d DISK",
    :long => "--disk DISK",
    :required => false 

  option :interval,
    :description => "Amount of time in seconds between each report", 
    :short => "-i interval",
    :long => "--interval interval",
    :default => 1

  def parse_results(output)
    metrics = {}
    res = output.split("Device:")
    result = res[2].split("\n")
    result.each do |line|
      line.strip!
      parts = line.split(" ")
      next unless parts.size == 12
      next if parts[0] == "rrqm/s:"
      key = parts[0]
      metrics[key] = {
        :rrqms => parts[1],
        :wrqms => parts[2],
        :rs => parts[3],
        :ws => parts[4],
        :rsecs => parts[5],
        :wsec_s => parts[6],
        :avgrq_sz => parts[7],
        :avgqu_sz => parts[8],
        :await => parts[9],
        :svctm => parts[10],
        :percent_util => parts[11]
        }
    end
    metrics
  end

  def run
    disk = config[:disk]
    interval = config[:interval]
    if disk.nil?
      raw = `iostat -x #{interval} 2`
      stats = parse_results(raw)
    else
      disk_short = File.basename(disk)
      raw = `iostat -xd #{disk} #{interval} 2`
      stats = parse_results(raw)
    end
     
    timestamp = Time.now.to_i

    stats.each do |disk, metrics|
      metrics.each do |metric, value|
        output [config[:scheme], "iostat", disk, metric].join("."), value, timestamp
      end
    end
    ok
  end 

end
