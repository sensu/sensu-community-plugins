#! /usr/bin/env ruby
#
#   check-dhcp
#
# DESCRIPTION:
#   This plugin checks DHCP server responses.
#   It must run as root to be able to bind to a listening port (udp 67 or 68)
#   By default it will simply check for a response to a discover broadcast
#   that is a valid DHCP::Message, ignoring contents.
#
#   If 'server' is specified, the check pretends to be a DHCP relay-agent, and
#   does a unicast request against a specific DHCP server.
#
#   The 'offer' or 'ipaddr' options can be used to test that the response
#   is an offer (of any address), or of a specific address.
#
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: net-dhcp
#   gem: socket
#   gem: ipaddr
#
# USAGE:
#   #YELLOW
#
# NOTES:
#
# LICENSE:
#   Matthew Richardson <m.richardson@ed.ac.uk>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'net/dhcp'
require 'ipaddr'
require 'socket'

class CheckDHCP < Sensu::Plugin::Check::CLI
  option :server,
         description: 'IP address of DHCP Server - will use unicast',
         short: '-s SERVER',
         long: '--server SERVER'

  option :timeout,
         description: 'Time to wait for DHCP responses (in seconds)',
         short: '-t TIMEOUT',
         long: '--timeout TIMEOUT',
         default: '10'

  option :offer,
         description: 'Must the DHCP response be an offer?',
         short: '-o',
         long: '--offer',
         boolean: true

  option :ipaddr,
         description: 'IP address the DHCP server should offer',
         short: '-i IPADDR',
         long: '--ipaddr IPADDR'

  option :debug,
         description: 'Enable verbose debugging output',
         short: '-d',
         long: '--debug',
         boolean: true

  def dhcp_discover
    request = DHCP::Discover.new

    listensock = UDPSocket.new
    sendsock = UDPSocket.new

    # Allows binding to ports that might be in use by local dhcp daemons
    listensock.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, true)
    sendsock.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, true)

    if config[:server]
      # Use unicast, and listen on dhcp server port (dhcp relay)
      sendaddr = config[:server]
      listenport = 67
    else
      # Use broadcast, and listen on dhcp client port
      sendsock.setsockopt(Socket::SOL_SOCKET, Socket::SO_BROADCAST, true)
      sendaddr = '<broadcast>'
      listenport = 68
    end

    listensock.bind('', listenport)
    sendsock.connect(sendaddr, 67)

    if config[:server]
      # Get the ip address we are connecting to the DHCP server from,
      # and set this as the gateway address in the DHCP message
      request.giaddr = IPAddr.new(sendsock.addr.last).to_i
    end

    # #YELLOW
    if config[:debug] # rubocop:disable IfUnlessModifier
      puts request
    end

    sendsock.send(request.pack, 0)

    begin
      # try to read from the socket
      data = listensock.recvfrom_nonblock(1500)
    rescue IO::WaitReadable
      # Socket not yet readable - wait until it is, or timeout reached
      # #YELLOW
      unless IO.select([listensock], nil, nil, config[:timeout].to_i) # rubocop:disable UnlessElse
        # timeout reached
        critical "Timeout reached awaiting response from DHCP server #{config[:server]}"
      else
        # try to read from the socket again
        data = listensock.recvfrom_nonblock(1500)
      end
    end

    listensock.close

    # Returns a DHCP::Message object, or nil if not parseable
    DHCP::Message.from_udp_payload(data[0])
  end

  def run
    response = dhcp_discover
    if response
      puts response if config[:debug]

      if config[:offer] || config[:ipaddr]
        # Is the response an DHCP Offer?
        if response.is_a?(DHCP::Offer)
          # #YELLOW
          if config[:ipaddr] # rubocop:disable BlockNesting
            offer = IPAddr.new(response.yiaddr, Socket::AF_INET).to_s
            # #YELLOW
            if offer == config[:ipaddr] # rubocop:disable BlockNesting
              ok "Received DHCP offer of IP address #{offer}"
            else
              critical "Received DHCP offer of IP address #{offer}, expected #{config[:ipaddr]}"
            end
          else
            ok 'Received DHCP offer'
          end
        else
          critical "Message received from #{config[:server]} not a DHCP offer"
        end
      else
        # Is response a DHCP message?
        if response.is_a?(DHCP::Message)
          ok 'Received DHCP response'
        else
          critical "Message received from #{config[:server]} not a valid DHCP response"
        end
      end
    else
      critical "No DHCP response received from #{config[:server]}"
    end
  end
end
