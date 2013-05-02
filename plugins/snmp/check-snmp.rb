#!/usr/bin/env ruby
# Check SNMP
# ===
#
# This is a simple SNMP check script for Sensu, We need to supply details like
# Server, port, SNMP community, and Limits
#
#
# Requires SNMP gem
#
# Examples:
#
#   check-snmp -h host -C community -O oid -w warning -c critical
#
#
#  Author Deepak Mohan Das   <deepakmdass88@gmail.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'snmp'

class CheckSNMP < Sensu::Plugin::Check::CLI

  option :host,
    :short => '-h host',
    :boolean => true,
    :default => "127.0.0.1"

  option :community,
    :short => '-C snmp community',
    :boolean =>true,
    :default => "public"

  option :objectid,
    :short => '-O OID',
    :default => "1.3.6.1.4.1.2021.10.1.3.1"

  option :warning,
    :short => '-w warning',
    :default => "10"

  option :critical,
    :short => '-c critical',
    :default => "20"

  def run
    manager = SNMP::Manager.new(:host => "#{config[:host]}", :community => "#{config[:community]}" )
    response = manager.get(["#{config[:objectid]}"])
    response.each_varbind do |vb|
      if "#{vb.value.to_s}".to_i >= "#{config[:critical]}".to_i
        critical "Critical state detected"
      end

      if (("#{vb.value.to_s}".to_i >= "#{config[:warning]}".to_i) && ("#{vb.value.to_s}".to_i < "#{config[:critical]}".to_i))
        warning "Warning state detected"
      end

      if ("#{vb.value.to_s}".to_i < "#{config[:warning]}".to_i)
        ok "All is well!"
      end
    end
    manager.close
  end
end
