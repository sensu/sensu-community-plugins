#!/usr/bin/env ruby
# SNMP Metrics 
# ===
#
# This is a simple script to collect metrics from a SNMP OID value
#
#
# Requires SNMP gem
#
# Examples:
#
#   check-snmp -h host -C community -O oid -p prefix -s suffix
#
#   Author: Johan van den Dorpe
#   Based on check-snmp.rb by Deepak Mohan Das   <deepakmdass88@gmail.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'snmp'

class SNMPGraphite < Sensu::Plugin::Metric::CLI::Graphite

  option :host,
    :short => '-h host',
    :boolean => true,
    :default => "127.0.0.1",
    :required => true

  option :community,
    :short => '-C snmp community',
    :boolean =>true,
    :default => "public"

  option :objectid,
    :short => '-O OID',
    :default => "1.3.6.1.4.1.2021.10.1.3.1",
    :required => true

  option :prefix,
    :short => '-p prefix',
    :default => "com.dneg",
    :description => 'prefix to attach to graphite path'

  option :suffix,
    :short => '-s suffix',
    :description => 'suffix to attach to graphite path',
    :required => true

  def run
    manager = SNMP::Manager.new(:host => "#{config[:host]}", :community => "#{config[:community]}" )
    response = manager.get(["#{config[:objectid]}"])
    response.each_varbind do |vb|
      output "#{config[:prefix]}.#{config[:host]}.#{config[:suffix]}", vb.value.to_f
    end
    manager.close
    ok
  end
end
