#!/usr/bin/env ruby
#
# Passenger Queue Check
# ===
#
#
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'

class CheckPassengerQueue < Sensu::Plugin::Check::CLI

  option :warn_over,
    :short => '-w N',
    :long => '--warn-over N',
    :description => 'Trigger a warning if over a number',
    :proc => proc {|a| a.to_i },
    :default => 0

  option :crit_over,
    :short => '-c N',
    :long => '--critical-over N',
    :description => 'Trigger a critical if over a number',
    :proc => proc {|a| a.to_i },
    :default => 1

  def run
    passenger_queue = %x[sudo passenger-status|grep 'Requests in queue'| awk '{print $4}']

    if !!config[:crit_over] && passenger_queue > config[:crit_over]
      critical msg
    elsif !!config[:warn_over] && passenger_queue > config[:warn_over]
      warning msg
    else
      ok
    end
  end
end
