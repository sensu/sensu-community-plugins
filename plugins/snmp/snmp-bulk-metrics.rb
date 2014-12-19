#!/usr/bin/env ruby
# SNMP Bulk Metrics
# ===
#
# This is a script to 'bulk walk' an SNMP OID value, collecting metrics
#
#
# Requires SNMP gem
#
# USAGE:
#
#   snmp-bulk-metrics -h host -C community -O oid1,oid2... -s suffix
#
#   Copyright 2014 Matthew Richardson <m.richardson@ed.ac.uk>
#   Based on snmp-metrics.rb by Double Negative Limited
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'snmp'

class SNMPGraphite < Sensu::Plugin::Metric::CLI::Graphite
  option :host,
         short: '-h host',
         boolean: true,
         default: '127.0.0.1',
         required: true

  option :community,
         short: '-C snmp community',
         boolean: true,
         default: 'public'

  option :objectid,
         short: '-O OID[,OID,OID...]',
         description: 'comma separated list of OIDs to bulkwalk',
         required: true

  option :prefix,
         short: '-p prefix',
         description: 'prefix to attach to graphite path'

  option :suffix,
         short: '-s suffix',
         description: 'suffix to attach to graphite path',
         required: true

  option :snmp_version,
         short: '-v version',
         description: 'SNMP version to use (SNMPv1, SNMPv2c (default))',
         default: 'SNMPv2c'

  option :graphite,
         short: '-g',
         description: 'Replace dots with underscores in hostname',
         boolean: true

  option :maxrepeat,
         short: '-m maxrepeat',
         description: 'Number of iterations to perform on repeating variables (defaults to 10)',
         default: 10

  option :nonrepeat,
         short: '-n non-repeaters',
         description: 'Number of supplied OIDs that should not be iterated over (defaults to 0)',
         default: 0

  option :timeout,
         short: '-t timeout (seconds) (defaults to 5)',
         default: 5

  def run
    oids = config[:objectid].split(',')
    begin
      manager = SNMP::Manager.new(host: "#{config[:host]}",
                                  community: "#{config[:community]}",
                                  version: config[:snmp_version].to_sym,
                                  timeout: config[:timeout].to_i)
      response = manager.get_bulk(config[:nonrepeat].to_i,
                                  config[:maxrepeat].to_i,
                                  oids)
    rescue SNMP::RequestTimeout
      unknown "#{config[:host]} not responding"
    rescue => e
      unknown "An unknown error occured: #{e.inspect}"
    end
    config[:host] = config[:host].gsub('.', '_') if config[:graphite]
    response.each_varbind do |vb|
      name = vb.oid
      name = "#{name}".gsub('.', '_') if config[:graphite]
      if config[:prefix]
        output "#{config[:prefix]}.#{config[:host]}.#{config[:suffix]}.#{name}", vb.value.to_f
      else
        output "#{config[:host]}.#{config[:suffix]}.#{name}", vb.value.to_f
      end
    end
    manager.close
    ok
  end
end
