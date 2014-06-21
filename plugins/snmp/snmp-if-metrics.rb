#!/usr/bin/env ruby
# SNMP Interface Metrics
# ===
#
# Collect device network interface metrics using the IF-MIB (RFC 2863) interface.
#
# This script uses the 64-bit "HC" (high capacity) metrics which I am assuming most
# modern devices probably support. If there is no HC support, use --low-capacity
# flag.
#
# Example
# -------
#
#   snmp-if-metrics.rb -C community -h host
#
# Only in/out octets are displayed by default to keep the number of metrics low. Additional
# Metrics can be generated:
#
# - `--include-down`: Output metrics for interfaces not marked up (ifOperStatus != 1).
#    By default only metrics for interfaces in the up state are printed.
# - `--include-errors`: Output error metrics such as in/out errors, discards, etc.
# - `--include-name`: Include the interface name with the interface index number when generating
#    the metric name. This can help identify interfaces in graphite when browsing.
# - `--include-packet-counts`: Output packet metrics.
# - `--include-speed`: Output a metric for the interface's speed. Useful when constructing
#   a view of an interfaces capacity in graphite.
# - `--version`: Set SNMP protocol version (SNMPv2c or SNMPv1)
# - `--low-capacity`: Use low capacity counters
#
# Copyright (c) 2013 Joe Miller
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'snmp'

def graphite_safe_name(name)
  name.gsub(/\W/, '_')
end

class SNMPIfStatsGraphite < Sensu::Plugin::Metric::CLI::Graphite

  option :host,
    :short => '-h host',
    :boolean => true,
    :default => "127.0.0.1",
    :required => true

  option :community,
    :short => '-C snmp community',
    :boolean =>true,
    :default => "public"

  option :scheme,
    :short => '-s SCHEME',
    :long => '--scheme SCHEME',
    :default => "snmp.interfaces",
    :description => 'prefix to attach to graphite path'

  option :include_pkt_metrics,
    :short => '-k',
    :long => '--include-packet-counts',
    :boolean => true,
    :default => false,
    :description => 'Include packets metrics, eg: IfInUcastPkts, IfOutUcastPkts, IfInBroadcastPkts, etc'

  option :include_speed,
    :short => '-s',
    :long => '--include-speed',
    :boolean => true,
    :default => false,
    :description => 'Output interface max speed (ifSpeed) metric'

  option :include_name,
    :short => '-n',
    :long => '--include-name',
    :boolean => true,
    :default => false,
    :description => 'append ifName to ifIndex when generating metric name, eg: "1__OUTSIDE"'

  option :include_error_metrics,
    :short => '-e',
    :long => '--include-errors',
    :boolean => true,
    :default => false,
    :description => 'Include error metrics in output'

  option :include_down_interfaces,
    :short => '-d',
    :long => '--include-down',
    :boolean => true,
    :default => false,
    :description => 'output metrics for all interfaces including those marked down'

  option :verbose,
    :short => '-v',
    :long => '--verbose',
    :boolean => true,
    :default => false,
    :description => 'verbose output for debugging'

  option :version,
    :short => '-V VERSION',
    :long => '--version VERSION',
    :default => :SNMPv2c,
    :description => 'SNMP version (SNMPv1 or SNMPv2c)',
    :proc => Proc.new {|ver| ver.intern }

  option :low_capacity,
    :long => '--low-capacity',
    :boolean => true,
    :default => false,
    :description => 'Use low capacity counters'

  def run
    ifTable_HC_columns = %w[
      ifHCInOctets ifHCOutOctets
      ifHCInUcastPkts ifHCOutUcastPkts
      ifHCInMulticastPkts ifHCOutMulticastPkts
      ifHCInBroadcastPkts ifHCOutBroadcastPkts
    ]
    ifTable_LC_columns = %w[
      ifInOctets ifOutOctets
      ifInUcastPkts ifOutUcastPkts
      ifInMulticastPkts ifOutMulticastPkts
      ifInBroadcastPkts ifOutBroadcastPkts
    ]
    ifTable_common_columns = %w[
      ifIndex ifOperStatus ifName ifDescr
      ifInErrors ifOutErrors ifInDiscards ifOutDiscards ifSpeed
    ]
    ifTable_columns = ifTable_common_columns +
      (config[:low_capacity] ? ifTable_LC_columns : ifTable_HC_columns)

    SNMP::Manager.open(:host => "#{config[:host]}", :community => "#{config[:community]}", :version => config[:version]) do |manager|
      manager.walk(ifTable_columns) do |row_array|
        # turn row (an array) into a hash for eaiser access to the columns
        row = Hash[*ifTable_columns.zip(row_array).flatten]
        puts row.inspect if config[:verbose]
        if_name = config[:include_name] ? "#{row['ifIndex'].value.to_s}__#{graphite_safe_name(row['ifName'].value.to_s)}" : row['ifIndex'].value.to_s

        next if row['ifOperStatus'].value != 1 && !config[:include_down_interfaces]

        in_octets = config[:low_capacity] ? "ifInOctets" : "ifHCInOctets"
        out_octets = config[:low_capacity] ? "ifOutOctets" : "ifHCOutOctets"
        output "#{config[:scheme]}.#{if_name}.#{in_octets}", row[in_octets].value
        output "#{config[:scheme]}.#{if_name}.#{out_octets}", row[out_octets].value

        if config[:include_speed]
          output "#{config[:scheme]}.#{if_name}.ifSpeed", row['ifSpeed'].value
        end

        if config[:include_error_metrics]
          output "#{config[:scheme]}.#{if_name}.ifInErrors", row['ifInErrors'].value
          output "#{config[:scheme]}.#{if_name}.ifOutErrors", row['ifOutErrors'].value
          output "#{config[:scheme]}.#{if_name}.ifInDiscards", row['ifInDiscards'].value
          output "#{config[:scheme]}.#{if_name}.ifOutDiscards", row['ifOutDiscards'].value
        end

        if config[:include_pkt_metrics]
          in_ucast_pkts = config[:low_capacity] ? "ifInUcastPkts" : "ifHCInUcastPkts"
          out_ucast_pkts = config[:low_capacity] ? "ifOutUcastPkts" : "ifHCOutUcastPkts"
          in_mcast_pkts = config[:low_capacity] ? "ifInMulticastPkts" : "ifHCInMulticastPkts"
          out_mcast_pkts = config[:low_capacity] ? "ifOutMulticastPkts" : "ifHCOutMulticastPkts"
          in_bcast_pkts = config[:low_capacity] ? "ifInBroadcastPkts" : "ifHCInBroadcastPkts"
          out_bcast_pkts = config[:low_capacity] ? "ifOutBroadcastPkts" : "ifHCOutBroadcastPkts"
          output "#{config[:scheme]}.#{if_name}.#{in_ucast_pkts}", row[in_ucast_pkts].value
          output "#{config[:scheme]}.#{if_name}.#{out_ucast_pkts}", row[out_ucast_pkts].value
          output "#{config[:scheme]}.#{if_name}.#{in_mcast_pkts}", row[in_mcast_pkts].value
          output "#{config[:scheme]}.#{if_name}.#{out_mcast_pkts}", row[out_mcast_pkts].value
          output "#{config[:scheme]}.#{if_name}.#{in_bcast_pkts}", row[in_bcast_pkts].value
          output "#{config[:scheme]}.#{if_name}.#{out_bcast_pkts}", row[out_bcast_pkts].value
        end
      end
    end
    ok
  end

end
