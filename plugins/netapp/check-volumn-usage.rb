#!/usr/bin/env ruby
# Check NetAPP volume usage percentage
# ===
#
# This is a simple NetAPP check script for Sensu based on snmp, We need to supply details like
# Server, port, Limits
#
#
# Requires SNMP gem
#
# Examples:
#
#   check-volume-usage -h host -C community -v SNMPversion -w warning -c critical -V Volumns
#   Volumns: the list of all volumes
#   
#
#  Author Autumn Wang   <shoujinwang@gmail.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'snmp'

class CheckVolumnUsage < Sensu::Plugin::Check::CLI
  option :host,
         short: '-h host',
         default: '127.0.0.1'

  option :community,
         short: '-C snmp community',
         default: 'public'

  option :warning,
         short: '-w warning',
         default: '10'

  option :critical,
         short: '-c critical',
         default: '20'

  option :snmp_version,
         short: '-v version',
         description: 'SNMP version to use (SNMPv1, SNMPv2c (default))',
         default: 'SNMPv2c'

  option :timeout,
         short: '-t timeout (seconds)',
         default: '1'
         
  option :exclude,
           short: '-x exclude match string',
           default: nil

  def run
    vol_usage_map = Hash.new('vol_usage_map')
    begin
      max_rows = 1024
      
      manager = SNMP::Manager.new(host: "#{config[:host]}",
                                  community: "#{config[:community]}",
                                  version: config[:snmp_version].to_sym,
                                  timeout: config[:timeout].to_i)
                                    
      volume_list_oid = '1.3.6.1.4.1.789.1.5.4.1.2'
      volume_list = manager.get_bulk(0, max_rows, volume_list_oid)
        
      volume_usage_oid = '1.3.6.1.4.1.789.1.5.4.1.6'
      response = manager.get_bulk(0, max_rows, volume_usage_oid)
      volume_usage = Hash.new("vol_usage")
      response.each_varbind do |vb|
        volume_usage[vb.name.to_s.sub('.6.','.2.')] = vb.value
      end
      volume_list.each_varbind do |vb|
        vol_name = vb.value.to_s
        vol_usage = volume_usage[vb.name.to_s]
        match_str = "#{config[:exclude]}".to_s
        if (config[:exclude] == nil) or (not vol_name =~ /#{match_str}/)
          vol_usage_map[vol_name] = vol_usage
        end
      end
    rescue SNMP::RequestTimeout
      unknown "#{config[:host]} not responding"
    rescue => e
      unknown "An unknown error occured: #{e.inspect}"
    end

    symbol = :>=
    
    warnings = Hash.new("warnings")
    criticals = Hash.new("criticals")
    
    vol_usage_map.each do |k, v|
      ## RED
      if "#{v}".to_i.send(symbol, "#{config[:critical]}".to_i)
        criticals[k] = v
      ## YELLOW
      elsif ("#{v}".to_i.send(symbol, "#{config[:warning]}".to_i)) && !("#{v}".to_i.send(symbol, "#{config[:critical]}".to_i))
        warnings[k] = v
      end
    end
    manager.close
    
    if criticals.length > 0
      msg = "Critical state detected : \n"
      criticals.each do |k, v|
        msg += "#{k} : #{v}%\n"
      end
      critical msg
    end
    if warnings.length > 0
      msg = "Warning state detected : \n"
      warnings.each do |k, v|
        msg += "#{k} : #{v}%\n"
      end
      warning msg
    end
    ok 'All is well!'
  end
end
