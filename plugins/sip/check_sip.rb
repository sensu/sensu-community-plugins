#! /usr/bin/env ruby
#
#   check-sip
#
# DESCRIPTION:
#   Connect to a SIP server and check we get a valid response to a request
#   for a SIP URI
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#
# USAGE:
#   #YELLOW
#
# NOTES:
#
# LICENSE:
#   Copyright 2013 Bashton Ltd <sam@bashton.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'socket'
require 'timeout'

class SIP < Sensu::Plugin::Check::CLI
  option :sipuri,
         description: 'SIP URI to check',
         short: '-u URI',
         long: '--uri URI',
         description: 'SIP URI in sip:123@hostname format',
         required: true

  option :timeout,
         short: '-t SECS',
         long: '--timeout SECS',
         description: 'Connection timeout',
         proc: proc(&:to_i),
         default: 10

  option :port,
         short: '-p PORT',
         long: '--port PORT',
         description: 'Destination port',
         proc: proc(&:to_i),
         default: 5060

  option :host,
         short: '-H HOSTNAME',
         long: '--host HOSTNAME',
         description: 'Host to connect to',
         required: true

  def build_request(ourhost, ourport, dsturi)
    tag = Array.new(6) { rand(36).to_s(36) }.join
    idtag = Array.new(6) { rand(36).to_s(36) }.join
    req = "OPTIONS #{dsturi} SIP/2.0\r\n"
    req += "Via: SIP/2.0/UDP #{ourhost}:#{ourport};branch=z9hG4bKhjhs8ass877\r\n"
    req += "Max-Forwards: 70\r\n"
    req += "To: #{dsturi}\r\n"
    req += "From: sip:sensu@#{ourhost}:#{ourport};tag=#{tag}\r\n"
    req += "Call-ID: #{idtag}@#{ourhost}\r\n"
    req += "CSeq: 1 OPTIONS\r\n"
    req += "Contact: <sip:sensu@#{ourhost}:#{ourport}>\r\n"
    req += "Accept: application/sdp\r\n"
    req += "Content-Length: 0\r\n\r\n" # rubocop:disable UselessAssignment
  end

  def check_response(response)
    header = response.split('\r\n')
    response_code = header[0].split(' ')[1]
    message "#{response_code}\n"
    response_code == '200' ? ok : warning
  end

  def run
    begin
      hostname = Socket.gethostbyname(Socket.gethostname).first
      s = UDPSocket.new
      s.connect(config[:host], config[:port])
      req = build_request(hostname, s.addr[1], config[:sipuri])
      response = ''
      timeout(config[:timeout]) do
        s.send(req, 0)
        response = s.recvfrom(1024)[0]
      end
    rescue Timeout::Error
      critical 'No response received'
      exit 1
    rescue => ex
      critical ex.message
      exit 1
    end
    check_response(response)
  end
end
