#!/usr/bin/env ruby
##
# Ceph OSD Metrics
# ===
#
# Dependencies:
#   - ceph client
#
# Dumps performance metrics from Ceph OSD admin socket into graphite-
# friendly format. It is up to the implementer to create the admin
# socket(s) and to handle the necessary permissions for sensu to access
# (sudo, etc.). In the default configuration, admin sockets are expected
# to reside in /var/run/ceph with a file format of ceph-osd.*.asok.
#
# If a different file search pattern is specificied, it is expected to
# have exactly one '*' wildcard denoting the OSD number.
#
# Copyright 2013 Cloudapt, LLC
#   Brian Clark <brian.clark@cloudapt.com> and
#   Mike Dawson <mike.dawson@cloudapt.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'json'
require 'English'

class CephOsdMetrics < Sensu::Plugin::Metric::CLI::Graphite

  option :scheme,
         :description => 'Metric naming scheme, text prepended to .$parent.$child',
         :long => '--scheme SCHEME',
         :default => 'ceph.osd'

  option :pattern,
         :description => 'Search pattern for sockets (/var/run/ceph/ceph-osd.*.asok)',
         :short => '-p',
         :long => '--pattern',
         :default => '/var/run/ceph/ceph-osd.*.asok'

  def output_data(h, leader)
    h.each_pair do |key, val|
      if val.is_a?(Hash)
        val.each do |k, v|
          output "#{config[:scheme]}.#{leader}.#{key}_#{k}", v
        end
      else
        output "#{config[:scheme]}.#{leader}.#{key}", val
      end
    end
  end

  def run
    Dir.glob(config[:pattern]).each do |socket|
      data = `ceph --admin-daemon #{socket} perf dump`
      if $CHILD_STATUS.exitstatus == 0
        # Left side of wildcard
        strip1 = config[:pattern].match(/^.*\*/).to_s.gsub(/\*/, '')
        # Right side of wildcard
        strip2 = config[:pattern].match(/\*.*$/).to_s.gsub(/\*/, '')
        osd_num = socket.gsub(strip1, '').gsub(strip2, '')
        JSON.parse(data).each do |k, v|
          k = k.gsub(/\/$/, '').gsub(/\//, '_')
          output_data(v, "#{osd_num}.#{k}")
        end
      end
    end
    ok
  end
end
