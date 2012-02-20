#!/usr/bin/env ruby
#
# Zookeeper check alive plugin
# ===
#
# This plugin checks if Zookeeper server is alive using the FOUR letter command 'ruok
#
# Copyright 2012 Abhijith G <abhi@runa.com> and Runa Inc.
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems'
require 'sensu-plugin/check/cli'
require 'socket'

class CheckZooKeeper < Sensu::Plugin::Check::CLI

  option :host,
         :description => "ZooKeeper host",
         :short => '-h',
         :long => '--host HOST',
         :default => 'localhost'

  option :port,
         :description => "ZooKeeper client port",
         :short => '-P',
         :long => '--port PORT',
         :default => 2181,
         :proc => proc { |a| a.to_i }
  
  def run
    res = zk_status

    if res["status"] == "ok"
      ok res["message"]
    elsif res["status"] == "critical"
      critical res["message"]
    else
      unknown res["message"]
    end
  end

  def ruok?
    res = nil
    host = config[:host]
    port = config[:port]
    TCPSocket.open(host, port) do |s|
      s.puts "ruok"
      res = s.read
    end
    "imok" == res
  end

  def zk_status
    begin
      if ruok?
        { "status" => "ok", "message" => "ZooKeeper server is alive" }
      else
        { "status" => "critical", "message" => "ZooKeeper server is dead" }
      end
    rescue Errno::ECONNREFUSED => e
      { "status" => "critical", "message" => e.message }
    rescue Exception => e
      { "status" => "unknown", "message" => e.message }
    end
  end
  
end
