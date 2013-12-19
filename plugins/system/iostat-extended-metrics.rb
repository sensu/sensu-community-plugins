#!/usr/bin/env ruby
#
# IOStatExtended Metrics Plugin
#
# This plugin collects iostat data for a specified disk or all disks.
# Output is in Graphite format. See `man iostat` for detailed
# explaination of each field.
#
# Peter Fern <ruby@0xc0dedbad.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'socket'

class IOStatExtended < Sensu::Plugin::Metric::CLI::Graphite

  option :scheme,
    :description => "Metric naming scheme, text to prepend to .$parent.$child",
    :long => "--scheme SCHEME",
    :default => "#{Socket.gethostname}.iostat"

  option :disk,
    :description => "Disk to gather stats for",
    :short => "-d DISK",
    :long => "--disk DISK",
    :required => false

  option :excludedisk,
    :description => "List of disks to exclude",
    :short => "-x DISK[,DISK]",
    :long => "--exclude-disk",
    :proc => proc { |a| a.split(',') }

  option :interval,
    :description => "Period over which statistics are calculated (in seconds)",
    :short => "-i SECONDS",
    :long => "--interval SECONDS",
    :default => 1

  def parse_results(raw)
    stats = {}
    key = nil
    headers = nil
    stage = :initial
    raw.each_line do |line|
      line.chomp!
      next if line.empty?

      case line
      when /^(avg-cpu):/
        stage = :cpu
        key = Regexp.last_match[1]
        headers = line.gsub(/%/, 'pct_').split(/\s+/)
        headers.shift
        next
      when /^(Device):/
        stage = :device
        headers = line.gsub(/%/, 'pct_').split(/\s+/).map{|h| h.gsub(/\//, '_per_')}
        headers.shift
        next
      end
      next if stage == :initial

      fields = line.split(/\s+/)

      if stage == :device
        key = fields.shift
      end
      stats[key] = Hash[headers.zip(fields.map{|f| f.to_f})]
    end
    stats
  end

  def run
    cmd = "iostat -x #{config[:interval]} 2"
    if config[:disk]
      cmd += " #{File.basename(config[:disk])}"
    end
    if config[:excludedisk]
      config[:excludedisk].each do |disk|
        cmd += " | grep -v #{disk}"
      end
    end
    stats = parse_results(`#{cmd}`)

    timestamp = Time.now.to_i

    stats.each do |disk, metrics|
      metrics.each do |metric, value|
        output [config[:scheme], disk, metric].join("."), value, timestamp
      end
    end
    ok
  end
end
