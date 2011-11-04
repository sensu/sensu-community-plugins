#!/usr/bin/env ruby

#
# This plugin checks to see if the OpsCode Chef client daemon is running
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
  running = true if proc.include?('chef-client')
end
if running
  puts 'CHEF CLIENT - OK - Chef client daemon is running'
  exit 0
else
  puts 'CHEF CLIENT - WARNING - Chef client daemon is NOT running'
  exit 1
end
