#!/usr/bin/env ruby
#
# Passenger Apache Check
# ===
#
#
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'

class CheckPassengerApache < Sensu::Plugin::Check::CLI

  option :warn_over,
    :short => '-w N',
    :long => '--warn-over N',
    :description => 'Trigger a warning if over a number',
    :proc => proc {|a| a.to_i }

  option :crit_over,
    :short => '-c N',
    :long => '--critical-over N',
    :description => 'Trigger a critical if over a number',
    :proc => proc {|a| a.to_i }

  option :warn_under,
    :short => '-W N',
    :long => '--warn-under N',
    :description => 'Trigger a warning if under a number',
    :proc => proc {|a| a.to_i },
    :default => 1

  option :crit_under,
    :short => '-C N',
    :long => '--critical-under N',
    :description => 'Trigger a critial if under a number',
    :proc => proc {|a| a.to_i },
    :default => 1

  def run
    apache_count = %x[sudo passenger-memory-stats | sed -n '/^-* Apache processes -*$/,/^$/p' | grep '/apache2 ' | wc -l]

    if !!config[:crit_under] && apache_count < config[:crit_under]
      critical msg
    elsif !!config[:crit_over] && apache_count > config[:crit_over]
      critical msg
    elsif !!config[:warn_under] && apache_count < config[:warn_under]
      warning msg
    elsif !!config[:warn_over] && apache_count > config[:warn_over]
      warning msg
    else
      ok
    end
  end
end
