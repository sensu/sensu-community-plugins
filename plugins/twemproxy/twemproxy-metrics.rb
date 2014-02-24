#!/usr/bin/env ruby
#
# Push twemproxy stats into graphite
# ===
#
# DESCRIPTION:
#   This plugin gets the stats data provided by twemproxy
#   and sends it to graphite.
#
#
# DEPENDENCIES:
#   sensu-plugin Ruby gem
#   socket       Ruby stdlib
#   timeout      Ruby stdlib
#   json         Ruby stdlib
#
# Copyright 2014 Toni Reina <areina0@gmail.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'socket'
require 'timeout'
require 'json'

class Twemproxy2Graphite < Sensu::Plugin::Metric::CLI::Graphite

  SKIP_ROOT_KEYS = ["service", "source", "version", "uptime", "timestamp"]

  option :host,
    :description => "Twemproxy stats host to connect to",
    :short       => "-h HOST",
    :long        => "--host HOST",
    :required    => false,
    :default     => "127.0.0.1"

  option :port,
    :description => "Twemproxy stats port to connect to",
    :short       => "-p PORT",
    :long        => "--port PORT",
    :required    => false,
    :proc        => proc { |p| p.to_i },
    :default     => 22222

  option :scheme,
    :description => "Metric naming scheme, text to prepend to metric",
    :short       => "-s SCHEME",
    :long        => "--scheme SCHEME",
    :required    => false,
    :default     => "#{Socket.gethostname}.twemproxy"

  option :timeout,
    :description => "Timeout in seconds to complete the operation",
    :short       => "-t SECONDS",
    :long        => "--timeout SECONDS",
    :required    => false,
    :proc        => proc { |p| p.to_i },
    :default     => 5

  def run
    begin
      Timeout.timeout(config[:timeout]) do
        sock = TCPSocket.new(config[:host], config[:port])
        data = JSON.parse(sock.read)
        pools = data.keys - SKIP_ROOT_KEYS

        pools.each do |pool_key|
          data[pool_key].each do |key, value|
            if value.is_a?(Hash)
              value.each do |key_server, value_server|
                output "#{config[:scheme]}.#{key}.#{key_server}", value_server
              end
            else
              output "#{config[:scheme]}.#{key}", value
            end
          end
        end
      end
      ok
    rescue Timeout::Error
      warning "Connection timed out"
    rescue Errno::ECONNREFUSED
      warning "Can't connect to #{config[:host]}:#{config[:port]}"
    end
  end

end
