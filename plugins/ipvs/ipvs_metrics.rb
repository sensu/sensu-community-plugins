#!/usr/bin/env ruby1.9.1
require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'socket'

class Graphite < Sensu::Plugin::Metric::CLI::Graphite

    option :scheme,
     :description => "Metric naming scheme, text to prepend to metric",
     :short => "-s SCHEME",
     :long => "--scheme SCHEME",
     :default => "#{Socket.gethostname}.ipvs.stats"


    def run
        ipvs = metrics_hash
        metrics = [ "TotalConn", "IncomingPkts", "OutgoingPkts", "IncomingBytes", "OutgoingBytes", "Conns_per_sec", "Pkts_per_sec", "IncomingBytes_per_sec", "OutgoingBytes_per_sec" ]

        #counter
        c = 0

        metrics.each do |parent|
            output [config[:scheme], parent].join("."), ipvs[c].hex
            c += 1
        end
        ok
    end

    def metrics_hash
       ipvs = Array.new
       ipvstop_output.each_line do |line|
           line.chomp!
           next if line.empty? || !(line.split & ipvs).empty?
           ipvs.push(line.gsub(/\s+/, " ").rstrip.split(" "))
       end
       ipvs.join(".").split(".")
    end

    def ipvstop_output
       output=`cat /proc/net/ip_vs_stats | egrep -v "Total|Conns"`
    end
 
 end
