#!/usr/bin/env ruby
#
# Check any procs running under bluepill control
# ===
#
# Checks the status of bluepill process
# Returns CRITICAL if proccess are down
# Returns WARNING if processes are starting or unmonitored (unless one or more
# process are down in which case CRITICAL is returned)
# Returns OK if all is well or bluepill is not in $PATH
#
# James Legg mail@jameslegg.co.uk
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'

class CheckBluepill < Sensu::Plugin::Check::CLI

  def run
    bluepill_groups = []
    warning_apps = []
    critical_apps = []

    # Check if Bluepill is installed
    `which bluepill`
    unless $?.success?
      ok "bluepill not installed"
    end

    # Bluepill groups
    bluepill_status = `bluepill status 2>&1`
    bluepill_status.each_line do |line|
      if line =~ /^\s \d\.\s/
        bluepill_groups.push(line.split(/^\s \d\.\s/)[1])
      elsif line =~ /^\w+\(pid:/
        bluepill_groups.push(line.split(/\(/)[0])
      end
    end
    # What apps is each bluepill group running
    bluepill_groups.each do |group|
      group = group.chomp
      cmd = "bluepill #{group} status"
      group_status = `#{cmd}`
      # For each real app in a group check it's status
      group_status.each_line do |line|
        if line =~ /(pid:)/
          case line
          when /unmonitored$/
            warning_apps.push("#{line}: unmonitored")
            next
          when /starting$/
            warning_apps.push("#{line}: starting")
            next
          when /down$/
            critical_apps.push("#{line}: down")
            next
          end
        end
      end
    end

    if critical_apps.any?
      critical "Bluepill app(s) #{critical_apps.join(',')} not running!"
    elsif warning_apps.any?
      warning "Bluepill app(s) #{warning_apps.join(',')} not running!"
    else
      ok "Bluepill normal"
    end
  end
end
