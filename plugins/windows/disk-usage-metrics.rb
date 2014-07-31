#!/usr/bin/env ruby
#
# Windows Disk Metric
# ===
#
# This plugin collects disk capacity metrics.
# Created to return values in same format as system/disk-usage-metric
#
# Copyright 2014 <alex.slynko@wonga.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'socket'

class DiskUsageMetric < Sensu::Plugin::Metric::CLI::Graphite

  option :scheme,
    :description => "Metric naming scheme, text to prepend to .$parent.$child",
    :long => "--scheme SCHEME",
    :default => "#{Socket.gethostname}.disk_usage"

  option :ignore_mnt,
    :description => 'Ignore mounts matching pattern(s)',
    :short => '-i MNT[,MNT]',
    :long => '--ignore-mount',
    :proc => proc { |a| a.split(',') }

  option :include_mnt,
    :description => 'Include only mounts matching pattern(s)',
    :short => '-I MNT[,MNT]',
    :long => '--include-mount',
    :proc => proc { |a| a.split(',') }

  BYTES_TO_MBYTES = 1024 * 1024

  def run
    `wmic logicaldisk get caption, drivetype, freespace, size`.split(/\n+/).each do |line|
      caption, drivetype, freespace, size = line.split
      next unless drivetype.to_i == 3
      next if config[:ignore_mnt] && config[:ignore_mnt].find { |x| mnt.match(x) }
      next if config[:include_mnt] && !config[:include_mnt].find { |x| mnt.match(x) }

      caption = "disk_#{caption[0]}"
      freespace = freespace.to_f / BYTES_TO_MBYTES
      size = size.to_f / BYTES_TO_MBYTES
      output [config[:scheme], caption, 'used'].join('.'), (size - freespace).round(2)
      output [config[:scheme], caption, 'avail'].join('.'), freespace.round(2)
      output [config[:scheme], caption, 'used_percentage'].join('.'), ((size - freespace) / size * 100).round
    end
    ok
  end
end
