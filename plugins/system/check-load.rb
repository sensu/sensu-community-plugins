#!/usr/bin/env ruby
#
# Check Linux system load
# ===
#
# Copyright 2012 Sonian, Inc <chefs@sonian.net>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'

class LoadAverage
  def initialize
    @avg = File.read('/proc/loadavg').split.take(3).map {|a| a.to_f } rescue nil
  end
  def failed?
    @avg.nil?
  end
  def exceed?(thresholds)
    @avg.zip(thresholds).any? {|a, t| a > t }
  end
  def to_s
    @avg.join(', ')
  end
end

class CheckLoad < Sensu::Plugin::Check::CLI

  option :warn,
    :short => '-w L1,L5,L15',
    :long => '--warn L1,L5,L15',
    :description => 'Load WARNING threshold, 1/5/15 min average',
    :proc => proc {|a| a.split(',').map {|t| t.to_f } },
    :default => [10, 20, 30]
  option :crit,
    :short => '-c L1,L5,L15',
    :long => '--crit L1,L5,L15',
    :description => 'Load CRITICAL threshold, 1/5/15 min average',
    :proc => proc {|a| a.split(',').map {|t| t.to_f } },
    :default => [25, 50, 75]

  def run
    avg = LoadAverage.new
    warning "Could not read load average from /proc" if avg.failed?
    message "Load average: #{avg}"
    critical if avg.exceed?(config[:crit])
    warning if avg.exceed?(config[:warn])
    ok
  end

end
