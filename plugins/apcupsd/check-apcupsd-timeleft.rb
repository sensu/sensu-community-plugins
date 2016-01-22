#!/usr/bin/env ruby
# check-apcupsd-timeleft.rb
# 
# Sensu plugin that checks the battery time (in minutes) using apcupsd deamon.
# <http://www.apcupsd.org/>
#
# Examples:
# check-apcupsd-timeleft.rb -w 5 -c 1
# 
# Send warning if the battery time is 5 minutes or less, critical if 1 minute or less.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'

class CheckApcupsd < Sensu::Plugin::Check::CLI

  option :warn,
    :short => '-w WARN',
    :proc => proc {|a| a.to_i },
    :default => 5

  option :crit,
    :short => '-c CRIT',
    :proc => proc {|a| a.to_i },
    :default => 10

  def run
    apcaccess = '/sbin/apcaccess'
    results = (%x[#{apcaccess} status | grep -i timeleft | awk '{print $3}' | awk -F'.' '{print $1}' ]).to_i    

    if results <= config[:warn] and results > config[:crit]
      warning "UPS Battery time is #{results} minutes"
    elsif results < config[:crit]
      critical "UPS Battery time is #{results} minutes"
    else
      ok "UPS Battery time is #{results} minutes"
    end
  end
end
