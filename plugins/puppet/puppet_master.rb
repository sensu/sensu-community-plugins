#!/usr/bin/env ruby
#
# Puppet Master Plugin
# ===
#
# This plugin checks to see if the Puppet Labs Puppet master is running
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
  running = true if proc.find { |p| /puppetmasterd|puppet master/ =~ p }
end
if running
  puts 'PUPPET MASTER - OK - Puppet master is running'
  exit 0
else
  puts 'PUPPET MASTER - WARNING - Puppet master is NOT running'
  exit 1
end
