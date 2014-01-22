#!/usr/bin/env ruby
#
# Checks DHCP servers
# ===
#
# DESCRIPTION:
#   This plugin checks DHCP server responses.
#   It must run as root to be able to listen for a response on udp port 68
#   By default it will simply check that localhost responds to a discover
#   with any valid DHCP::Message, ignoring contents.
#
#   The 'offer' or 'ipaddr' options can be used to test that the response
#   is an offer (of any address), or of a specific address.
#
# OUTPUT:
#   plain-text
#
# PLATFORMS:
#   linux
#
# DEPENDENCIES:
#   net-dhcp ipaddr socket sensu-plugin Ruby gem
#
# Author: Matthew Richardson <m.richardson@ed.ac.uk>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'net/dhcp'
require 'ipaddr'
require 'socket'

class CheckDHCP < Sensu::Plugin::Check::CLI

  option :server,
    :description => "IP address of DHCP Server",
    :short => '-s SERVER',
    :long => '--server SERVER',
    :default => '127.0.0.1'

  option :timeout,
    :description => "Time to wait for DHCP responses (in seconds)",
    :short => '-t TIMEOUT',
    :long => '--timeout TIMEOUT',
    :default => '10'

  option :offer,
    :description => "Must the DHCP response be an offer?",
    :short => '-o',
    :long => '--offer',
    :boolean => true

  option :ipaddr,
    :description => "IP address the DHCP server should offer",
    :short => '-i IPADDR',
    :long => '--ipaddr IPADDR'

  def dhcp_discover

    request = DHCP::Discover.new

    sock = UDPSocket.new
    sock.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, true)
    sock.bind('', 68)
    sock.send(request.pack, 0, config[:server], 67)

    begin
      # try to read from the socket
      data = sock.recvfrom_nonblock(1500)
    rescue IO::WaitReadable
      # Socket not yet readable - wait until it is, or timeout reached
      unless IO.select([sock], nil, nil, config[:timeout].to_i)
        # timeout reached
        critical "Timeout reached awaiting response from DHCP server #{config[:server]}"
      else
        # try to read from the socket again
        data = sock.recvfrom_nonblock(1500)
      end
    end
    sock.close

    # Returns a DHCP::Message object, or nil if not parseable
    DHCP::Message.from_udp_payload(data[0])

  end

  def run
    response = dhcp_discover
    if response
      if config[:offer] || config[:ipaddr]
        # Is the response an DHCP Offer?
        if response.is_a?(DHCP::Offer)
          if config[:ipaddr]
            offer = IPAddr.new(response.yiaddr, Socket::AF_INET).to_s
            if offer == config[:ipaddr]
              ok "Received DHCP offer of IP address #{offer}"
            else
              critical "Received DHCP offer of IP address #{offer}, expected #{config[:ipaddr]}"
            end
          else
            ok "Received DHCP offer"
          end
        else
          critical "Message received from #{config[:server]} not a DHCP offer"
        end
      else
        # Is response a DHCP message?
        if response.is_a?(DHCP::Message)
          ok "Received DHCP response"
        else
          critical "Message received from #{config[:server]} not a valid DHCP response"
        end
      end
    else
      critical "No DHCP response received from #{config[:server]}"
    end
  end
end
