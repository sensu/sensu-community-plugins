#!/usr/bin/env ruby
#
# System Load Stats Plugin
# ===
#
# This plugin uses df to collect disk capacity metrics
# disk-usage-metrics.rb looks at /proc/stat which doesnt hold capacity metricss.
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.
#
# Based on disk-capacity-metrics.rb by bhenerey and nstielau
# The difference here being how the key is defined in graphite and the
# size we emit to graphite(now using megabytes). Also i dropped inode info.
# Using this as an example
# Filesystem                                 Size  Used Avail Use% Mounted on
# /dev/mapper/precise64-root                  79G  3.5G   72G   5% /
# /dev/sda1                                  228M   25M  192M  12% /boot
# The keys with this plugin will be
#  disk_usage.root and disk_usage.root.boot instead of
#  disk.dev.mapper.precise64-root and disk.sda1
# rubocop:disable HandleExceptions

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'socket'

class DiskUsageMetrics < Sensu::Plugin::Metric::CLI::Graphite

  option :scheme,
         :description => "Metric naming scheme, text to prepend to .$parent.$child",
         :long => "--scheme SCHEME",
         :default => "#{Socket.gethostname}.disk_usage"

  def run
    # Get disk usage from df with used and avail in megabytes
    `df -PBM`.split("\n").drop(1).each do |line|
      timestamp = Time.now.to_i
      _, _, used, avail, used_p, mnt = line.split

      unless /\/sys|\/dev|\/run/.match(mnt)
        # If mnt is only / replace that with root if its /tmp/foo
        # replace first occurance of / with root.
        mnt = mnt.length == 1 ? 'root' : mnt.gsub(/^\//, 'root.')

        # Fix subsequent slashes
        mnt = mnt.gsub '/', '.'

        output [config[:scheme], mnt, 'used'].join("."), used.gsub('M', ''), timestamp
        output [config[:scheme], mnt, 'avail'].join("."), avail.gsub('M', ''), timestamp
        output [config[:scheme], mnt, 'used_percentage'].join("."), used_p.gsub('%', ''), timestamp
      end
    end
    ok
  end
end
