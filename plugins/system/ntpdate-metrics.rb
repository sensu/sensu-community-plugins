#!/usr/bin/env ruby
#
# Push ntpdate -q stats into graphite
# ===
#
# Copyright 2014 Mitsutoshi Aoe <maoe@foldr.in>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'socket'

class NtpdateMetrics < Sensu::Plugin::Metric::CLI::Graphite
  option :server,
    :description => 'NTP server(s)',
    :long => '--server SERVER1[,SERVER2,..]',
    :default => ['localhost'],
    :proc => Proc.new {|str| str.split(',') }

  option :scheme,
    :description => "Metric naming scheme, text to prepend to metric",
    :short => "-s SCHEME",
    :long => "--scheme SCHEME",
    :default => Socket.gethostname

  def run
    stats = get_ntpdate(config[:server])
    critical "Failed to get/parse ntpdate -q output" if stats[:delay].nil?
    stats.each do |key, value|
      output([config[:scheme], :ntpdate, key].join('.'), value)
    end
    ok
  end

  def get_ntpdate(servers)
    float = /-?\d+\.\d+/
    pattern = /offset (#{float}), delay (#{float})/
    stats = { :offset => nil, :delay => nil }
    `ntpdate -q #{servers.join(' ')}`.scan(pattern).each do |parsed|
      offset, delay = parsed
      offset = Float(offset)
      delay = Float(delay)
      if stats[:delay].nil? || delay <= stats[:delay]
        stats[:delay] = delay
        stats[:offset] = offset
      end
    end
    stats
  end
end
