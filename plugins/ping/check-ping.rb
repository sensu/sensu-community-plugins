#!/usr/bin/env ruby
# Check-ping
# ===
#
# This is a simple Ping check script for Sensu, Currently works with
#  ICMP as well as HTTP ping.
#
# Requires "net-ping" gem
#
# Examples:
#
#   check-ping -h host -t type -p port    => port option is for HTTP ping
#   
#  Deaful host is "google.com", change to if you dont want to pass host  
# option 
#  Author Deepak Mohan Dass   <deepakmdass88@gmail.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'net/ping'

class CheckPING < Sensu::Plugin::Check::CLI


  option :port, 
    :short => '-p port', 
    :default => "80"

  option :host, 
    :short => '-h host', 
    :default => "google.com"

  option :type, 
    :short => '-t type', 
    :default => 'HTTP'

  def run
    if "#{config[:type]}" == "HTTP"
      port_num = eval "#{config[:port]}"
      pt = Net::Ping::HTTP.new("http://#{config[:host]}", port="#{port_num}", timeout=10)
        if pt.ping?
  	  msg = "HTTP ping successful"
	  ok msg
	else
          msg = "HTTP ping unsuccessful"
	critical msg 
	end

    else
      pn = Net::Ping::ICMP.new("#{config[:host]}")
        if pn.ping?
  	  msg = "ICMP ping successful"
	  ok msg
	else
  	  msg = "ICMP ping unsuccessful"
	  critical msg
	end
    end
  end
end
