#!/usr/bin/env ruby
#
# TCP socket state metrics
# ===
#
# Fetch metrics on TCP socket states from netstat. This is particularly useful
# on high-traffic web or proxy servers with large numbers of short-lived TCP
# connections coming and going.
#
# Example
# -------
#
# $ ./metrics-netstat-tcp.rb --scheme servers.hostname
#  servers.hostname.UNKNOWN      0     1350496466
#  servers.hostname.ESTABLISHED  235   1350496466
#  servers.hostname.SYN_SENT     0     1350496466
#  servers.hostname.SYN_RECV     1     1350496466
#  servers.hostname.FIN_WAIT1    0     1350496466
#  servers.hostname.FIN_WAIT2    53    1350496466
#  servers.hostname.TIME_WAIT    10640 1350496466
#  servers.hostname.CLOSE        0     1350496466
#  servers.hostname.CLOSE_WAIT   7     1350496466
#  servers.hostname.LAST_ACK     1     1350496466
#  servers.hostname.LISTEN       16    1350496466
#  servers.hostname.CLOSING      0     1350496466
#
# Acknowledgements
# ----------------
# - Code for parsing Linux /proc/net/tcp from Anthony Goddard's ruby-netstat:
#   https://github.com/agoddard/ruby-netstat
#
# Copyright 2012 Joe Miller <https://github.com/joemiller>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.
#
# rubocop:disable FavorUnlessOverNegatedIf

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'socket'

TCP_STATES = {
  '00' => 'UNKNOWN',  # Bad state ... Impossible to achieve ...
  'FF' => 'UNKNOWN',  # Bad state ... Impossible to achieve ...
  '01' => 'ESTABLISHED',
  '02' => 'SYN_SENT',
  '03' => 'SYN_RECV',
  '04' => 'FIN_WAIT1',
  '05' => 'FIN_WAIT2',
  '06' => 'TIME_WAIT',
  '07' => 'CLOSE',
  '08' => 'CLOSE_WAIT',
  '09' => 'LAST_ACK',
  '0A' => 'LISTEN',
  '0B' => 'CLOSING'
}

class NetstatTCPMetrics < Sensu::Plugin::Metric::CLI::Graphite

  option :scheme,
    :description => "Metric naming scheme, text to prepend to metric",
    :short => "-s SCHEME",
    :long => "--scheme SCHEME",
    :default => "#{Socket.gethostname}.tcp"

  option :port,
    :description => "Port you wish to get metrics for",
    :short => "-p PORT",
    :long => "--port PORT",
    :proc => proc {|a| a.to_i }

  def netstat(protocol = 'tcp')
    state_counts = Hash.new(0)
    TCP_STATES.each_pair { |hex, name| state_counts[name] = 0 }

    File.open('/proc/net/' + protocol).each do |line|
      line.strip!
      if m = line.match(/^\s*\d+:\s+(.{8}):(.{4})\s+(.{8}):(.{4})\s+(.{2})/) # rubocop:disable AssignmentInCondition
        connection_state = m[5]
        connection_port = m[2].to_i(16)
        connection_state = TCP_STATES[connection_state]
        if config[:port] && config[:port] == connection_port
          state_counts[connection_state] += 1
        elsif !config[:port]
          state_counts[connection_state] += 1
        end
      end
    end
    state_counts
  end

  def run
    timestamp = Time.now.to_i
    netstat('tcp').each do |state, count|
      graphite_name = config[:port] ? "#{config[:scheme]}.#{config[:port]}.#{state}" :
        "#{config[:scheme]}.#{state}"
      output "#{graphite_name}", count, timestamp
    end
    ok
  end

end
