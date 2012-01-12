#!/usr/bin/env ruby
#
# Check Memcached stats
# ===
#
# Copyright 2012 AJ Christensen <aj@junglist.gen.nz>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require "rubygems" if RUBY_VERSION < "1.9.0"
require "sensu-plugin/check/cli"
require "socket"
require "timeout"

class MemcachedStats < Sensu::Plugin::Check::CLI

  option :port,
  :short => "-p PORT",
  :long => "--port PORT",
  :description => "Memcached Port to connect to",
  :proc => proc {|p| p.to_i },
  :required => true

  def run
    begin
      status = Timeout::timeout(30) do
        TCPSocket.open("localhost", config[:port]) do |socket|
          socket.print "stats\r\n"
          socket.close_write
          socket.read
        end
      end
    rescue Timeout::Error
      warning "timed out connecting to memcached on port #{config[:port]}"
    else
      ok "memcached stats protocol responded in a timely fashion"
    end

  end
end
