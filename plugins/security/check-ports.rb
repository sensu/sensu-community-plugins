#!/usr/bin/env ruby
#
# check-ports.rb
#   Check to see the status of port(s) with nmap.
# ===
#
# Description
#   Fetch port status using nmap. This check is good for catching bad network ACLs
#   or service down events for network resources.
#
# Dependancies
# - nmap (tested with Nmap 6.25)
#
# Examples
# -------
#
#   $ ./check-ports.rb --host some_server --ports 5671,5672
#
# Pass condition
#   CheckPorts OK: open:5671,5672
#
# Fail condition
#   CheckPorts WARNING: open:5671 filtered:5672
#
# Copyright 2013 GoDaddy.com, LLC <jjmanzer@godaddy.com>
# Released under the same terms as Sensu (the MIT license); see LICENSE for details.

require 'open3'
require 'sensu-plugin/check/cli'
require 'json'

class CheckPorts < Sensu::Plugin::Check::CLI

  option :host,
    :description => 'Resolving name or IP address of target host',
    :short       => '-h HOST',
    :long        => '--host HOST',
    :default     => 'localhost'

  option :ports,
    :description => 'TCP port(s) you wish to get status for',
    :short       => '-t PORT,PORT...',
    :long        => '--ports PORT,PORT...'

  def run

    stdout, stderr = Open3.capture3(
      ENV,
      "nmap -P0 -p #{ config[:ports] } #{ config[:host] }"
    )

    case stderr
    when /Failed to resolve/
      critical 'cannot resolve the target hostname'
    end

    port_checks = {}
    check_pass  = true

    stdout.split("\n").each do |line|

      line.scan(/(\d+).tcp\s+(\w+)\s+(\w+)/).each do |status|
        port_checks[status[1]] ||= []
        port_checks[status[1]].push status[0]
        check_pass = false unless status[1]['open']
      end

    end

    result = port_checks.map { |state, ports| "#{ state }:#{ ports.join(',') }" }.join(' ')

    if check_pass
      ok result
    else
      warning result
    end

  end

end
