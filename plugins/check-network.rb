#!/usr/bin/env ruby
#
#   check-network
#
# DEPENDENCIES:
#   ifstat

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'

class CheckNetwork < Sensu::Plugin::Check::CLI

  option :interface,
    :short => '-i INTERFACE',
    :long => '--interface INTERFACE',
    :description => 'Interface name'

  option :warn,
    :short => '-w D100,U20',
    :long => '--warn D100,U20',
    :description => 'Network WARNING threshold, 100Kb/s Down 20Kb/s Up',
    :proc => proc {|a| a.split(',').map {|t| t.to_f } },
    :default => [100, 20]

  option :crit,
    :short => '-c D100,U20',
    :long => '--crit D100,U20',
    :description => 'Network CRITICAL threshold, 100Kb/s Down 20Kb/s Up',
    :proc => proc {|a| a.split(',').map {|t| t.to_f } },
    :default => [500, 30]

  def run

    interface = config[:interface] || 'eth0'
    exceed = Proc.new {|a, t| a > t }

    network_rate = `ifstat -i #{interface} 0.1 1 | tail -1`.split
    network_rate.map! {|x| x.to_f}

    puts "#{interface}"
    message "#{network_rate[0]}Kb/s Downstream and #{network_rate[1]}Kb/s Upstream"

    critical if network_rate.zip(config[:crit]).any? &exceed
    warning if network_rate.zip(config[:warn]).any? &exceed
    ok
  end

end
