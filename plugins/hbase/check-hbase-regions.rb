#!/usr/bin/hbase org.jruby.Main
#
# HBase regions plugin
# ===
#
# This plugin checks the number of regions on a regionserver
#
# Copyright 2011 Runa Inc
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'java'
require 'pp'

include Java
include_class('java.lang.Integer') { |package, name| "J#{name}" }
include_class('java.lang.Long')    { |package, name| "J#{name}" }
include_class('java.lang.Boolean') { |package, name| "J#{name}" }

import org.apache.hadoop.hbase.client.HBaseAdmin
import org.apache.hadoop.hbase.client.HTable
import org.apache.hadoop.hbase.HBaseConfiguration
import org.apache.hadoop.hbase.util.Bytes
import org.apache.log4j.Logger

packages = ["org.apache.zookeeper", "org.apache.hadoop", "org.apache.hadoop.hbase"]

packages.each do |package|
  logger = org.apache.log4j.Logger.getLogger(package)
  logger.setLevel(org.apache.log4j.Level::ERROR);
end

module SensuUtils
  # Copied from sensu-plugin

  EXIT_CODES = {
    'OK' => 0,
    'WARNING' => 1,
    'CRITICAL' => 2,
    'UNKNOWN' => 3,
  }

  def output(fn, *args)
    puts "#{fn.upcase}: #{args}"
  end

  EXIT_CODES.each do |status, code|
    define_method(status.downcase) do |*args|
      output(status, *args)
      exit(code)
    end
  end

end

include SensuUtils

def regionserver_info
  conf  = HBaseConfiguration.new
  admin = HBaseAdmin.new(conf)

  status = admin.getClusterStatus
  status.getServerInfo.map do |server|
    { :hostname => server.getServerAddress.getHostname,
      :regions => server.getLoad.getNumberOfRegions
    }
  end
end

def check_threshold(info)
  case info[:regions]
  when config[:ok]..config[:warning]
    { :status => :ok, :msg => "Regions: #{info.inspect}" }
  when config[:warning]..config[:critical]
    { :status => :warning, :msg => "Regions: #{info.inspect}" }
  else
    { :status => :critical, :msg => "Regions: #{info.inspect}" }
  end
end

@config = { :ok => 0, :warning => 900, :critical => 1000 }

class Array
  def second
    self[1]
  end
end

def config
  @config
end

def run
  status = regionserver_info.map { |x| check_threshold(x) }

  msg = "\n" + status.map { |x| x[:msg] }.join("\n")

  if status.any? { |x| x[:status] == :critical }
    critical msg
  elsif status.any? { |x| x[:status] == :warning }
    warning msg
  else
    ok msg
  end

end

@config[:warning]  = ARGV.first.to_i if ARGV.first
@config[:critical] = ARGV.second.to_i if ARGV.second

run
