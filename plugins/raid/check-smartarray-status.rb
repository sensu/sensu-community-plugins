#!/usr/bin/env ruby
#
# Check HP SmartArray Status Plugin
# ===
#
# Checks status for all HDDs in all SmartArray controllers.
#
# hpacucli requires root permissions.
#
# Create a file named /etc/sudoers.d/hpacucli with this line inside :
# sensu ALL=(ALL) NOPASSWD: /usr/sbin/hpacucli
#
# You can get Debian/Ubuntu hpacucli packages here - http://hwraid.le-vert.net/
#
# Copyright 2014 Alexander Bulimov <lazywolf0@gmail.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'open3'

class CheckSmartArrayStatus < Sensu::Plugin::Check::CLI
  def initialize
    super
    @binary = 'sudo -n -k hpacucli'
    @controllers = []
    @good_disks = []
    @bad_disks = []
  end

  def execute(cmd)
    captured_stdout = ''
    # we use popen2e because hpacucli does not use stderr for errors
    exit_status = Open3.popen2e(ENV, cmd) do |stdin, stdout, wait_thr|
      stdin.close
      captured_stdout = stdout.read
      wait_thr.value
    end
    [exit_status, captured_stdout]
  end

  def parse_controllers!(data)
    data.lines.each do |line|
      unless line.empty?
        captures = line.match(/Slot\s+([0-9]+)/)
        @controllers << captures[1] if !captures.nil? && captures.length > 1
      end
    end
  end

  def parse_disks!(data, controller)
    # #YELLOW
    data.lines.each do |line|    # rubocop:disable Style/Next
      unless line.empty?
        splitted = line.split
        if /^physicaldrive$/ =~ splitted[0]
          status = splitted[-1]
          disk = 'ctrl ' + controller + ' ' + line.strip
          if status == 'OK'
            @good_disks << disk
          else
            @bad_disks << disk
          end
        end
      end
    end
  end

  def run
    exit_status, raw_data = execute "#{@binary} ctrl all show status"
    unknown "hpacucli command failed - #{raw_data}" unless exit_status.success?
    parse_controllers! raw_data

    @controllers.each do |controller|
      exit_status, raw_data = execute "#{@binary} ctrl slot=#{controller} pd all show status"
      unknown "hpacucli command failed - #{raw_data}" unless exit_status.success?
      parse_disks! raw_data, controller
    end

    if @bad_disks.empty?
      data = @good_disks.length
      ok "All #{data} found disks are OK"
    else
      data = @bad_disks.join(', ')
      bad_count = @bad_disks.length
      good_count = @good_disks.length
      total_count = bad_count + good_count
      critical "#{bad_count} of #{total_count} disks are in bad state - #{data}"
    end
  end
end
