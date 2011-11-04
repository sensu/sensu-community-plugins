#!/usr/bin/env ruby

#
# This plugin checks to see if the Puppet Labs Puppet agent is running
#

`which tasklist`
case
when $? == 0
  procs = `tasklist`
else
  procs = `ps aux`
end
running = false
procs.each_line do |proc|
  running = true if proc.grep(/puppetd|puppet agent/)
end
if running
  puts 'PUPPET AGENT - OK - Puppet agent is running'
  exit 0
else
  puts 'PUPPET AGENT - WARNING - Puppet agent is NOT running'
  exit 1
end
