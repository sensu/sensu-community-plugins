#!/usr/bin/env ruby
#
# Check Memcached stats
# ===
#
# Copyright 2012 AJ Christensen <aj@junglist.gen.nz>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'socket'
require 'timeout'

class MemcachedStats < Sensu::Plugin::Check::CLI

  option :host,
         :short       => "-h HOST",
         :long        => "--host HOST",
         :description => "Memcached Host to connect to",
         :required    => false,
         :default     => '127.0.0.1'

  option :port,
         :short       => "-p PORT",
         :long        => "--port PORT",
         :description => "Memcached Port to connect to",
         :proc        => proc { |p| p.to_i },
         :default     => 11211

  def run
    begin
      Timeout.timeout(30) do
        TCPSocket.open(config[:host], config[:port]) do |socket|
          socket.print "stats\r\n"
          socket.close_write
          socket.read
        end
      end
    rescue Timeout::Error
      warning "timed out connecting to memcached on port #{config[:port]}"
    rescue
      critical "Can't connect to port #{config[:port]}"
    else
      ok "memcached stats protocol responded in a timely fashion"
    end
  end

end
