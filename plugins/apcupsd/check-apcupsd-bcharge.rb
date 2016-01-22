#!/usr/bin/env ruby
# check-apcupds-bcharge.rb
# 
# Sensu plugin that checks the battery charge and battery time using apcupsd deamon.
# <http://www.apcupsd.org/>
#
# Examples:
# check-apcupds-bcharge.rb -w 80 -c 50
#
# Send warning if the battery charge is less then 80%, critical if less then %50.

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
    results = (%x[#{apcaccess} status | grep -i bcharge | awk '{print $3}' | awk -F'.' '{print $1}' ]).to_i    
    
    if results < config[:crit]
      critical "UPS Battery Charge is at #{results}%"
    elsif results < config[:warn]
      warning "UPS Battery Charge is at #{results}%"
    else
      ok "UPS Battery Charge is at #{results}%" 
    end
  end
end
