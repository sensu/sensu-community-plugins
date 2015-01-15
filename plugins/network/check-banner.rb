#! /usr/bin/env ruby
#
#   <script name>
#
# DESCRIPTION:
#   what is this thing supposed to do, monitor?  How do alerts or
#   alarms work?
#
# OUTPUT:
#   plain text, metric data, etc
#
# PLATFORMS:
#   Linux, Windows, BSD, Solaris, etc
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: <?>
#
# USAGE:
#   example commands
#
# NOTES:
#   Does it behave differently on specific platforms, specific use cases, etc
#
# LICENSE:
#   <your name>  <your email>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

# !/usr/bin/env ruby
#
# Check Banner
# ===
#
# Connect to a TCP port, read one line, test it against a pattern.
# Useful for SSH, ZooKeeper, etc.
#
# Copyright 2012 Sonian, Inc <chefs@sonian.net>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'socket'
require 'timeout'

class CheckBanner < Sensu::Plugin::Check::CLI
  option :host,
         short: '-H HOSTNAME',
         long: '--hostname HOSTNAME',
         description: 'Host to connect to',
         default: 'localhost'

  option :port,
         short: '-p PORT',
         long: '--port PORT',
         proc: proc(&:to_i),
         default: 22

  option :write,
         short: '-w STRING',
         long: '--write STRING',
         description: 'write STRING to the socket'

  option :pattern,
         short: '-q PAT',
         long: '--pattern PAT',
         description: 'Pattern to search for',
         default: 'OpenSSH'

  option :timeout,
         short: '-t SECS',
         long: '--timeout SECS',
         description: 'Connection timeout',
         proc: proc(&:to_i),
         default: 30

  def acquire_banner
    timeout(config[:timeout]) do
      sock = TCPSocket.new(config[:host], config[:port])
      sock.puts config[:write] if config[:write]
      sock.readline
    end
  rescue Errno::ECONNREFUSED
    critical "Connection refused by #{config[:host]}:#{config[:port]}"
  rescue Timeout::Error
    critical 'Connection or read timed out'
  rescue Errno::EHOSTUNREACH
    critical 'Check failed to run: No route to host'
  rescue EOFError
    critical 'Connection closed unexpectedly'
  end

  def run
    banner = acquire_banner
    message banner
    banner =~ /#{config[:pattern]}/ ? ok : warning
  end
end
