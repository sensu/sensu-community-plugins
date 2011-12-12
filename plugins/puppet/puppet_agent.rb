#!/usr/bin/env ruby
#
# Puppet Agent Plugin
# ===
#
# This plugin checks to see if the Puppet Labs Puppet agent is running
#
# Copyright 2011 James Turnbull
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

`which tasklist`
case
when $? == 0
  procs = `tasklist`
else
  procs = `ps aux`
end
running = false
procs.each_line do |proc|
  running = true if proc.find { |p| /puppetd|puppet agent/ =~ p }
end
if running
  puts 'PUPPET AGENT - OK - Puppet agent is running'
  exit 0
else
  puts 'PUPPET AGENT - WARNING - Puppet agent is NOT running'
  exit 1
end
