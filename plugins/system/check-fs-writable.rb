#! /usr/bin/env ruby
#
# check-fs-writable
#
# DESCRIPTION:
# This plugin checks that a filesystem is writable. Useful for checking for stale NFS mounts.
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   all
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: tempfile
#
# USAGE:
#   ./check-fs-writable.rb --auto  (check all nfs mounts in fstab)
#   ./check-fs-writable.rb --auto  --ignore /mnt/ignorethis,/home (check nfs mounts in fstab, except those specified in --ignore)
#   ./check-fs-writable.rb --dir /,/var,/usr,/home  (check a defined list of directories)
#
# NOTES:
#
# LICENSE:
#   Copyright 2014 Yieldbot, Inc  <devops@yieldbot.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'tempfile'

class CheckFSWritable < Sensu::Plugin::Check::CLI
  option :dir,
         description: 'Directory to check for writability',
         short: '-d DIRECTORY',
         long: '--directory DIRECTORY',
         proc: proc { |a| a.split(',') }

  option :auto,
         description: 'Auto discover mount points via fstab',
         short: '-a',
         long: '--auto-discover'

  option :ignore,
         description: 'Directory to ignore during auto-discover',
         short: '-i DIRECTORY',
         long: '--ignore DIRECTORY',
         proc: proc { |a| a.split(',') }

  option :debug,
         description: 'Print debug statements',
         long: '--debug'

  def initialize
    super
    @crit_pt_proc = []
    @crit_pt_test = []
  end

  def usage_summary
    if @crit_pt_test.empty? && @crit_pt_proc.empty?
      ok 'All filesystems are writable'
    elsif @crit_pt_test || @crit_pt_proc
      critical "The following file systems are not writeable: #{ @crit_pt_test }, #{@crit_pt_proc}"
    end
  end

  def acquire_mnt_pts
    `grep '\snfs\s' /proc/self/mounts | awk '{print $2, $4}' | awk -F, '{print $1}' | awk '{print $1, $2}'`
  end

  def rw_in_proc?(mount_info)
    mount_info.each do |pt|
      @crit_pt_proc <<  "#{ pt.split[0] }" if pt.split[1] != 'rw'
    end
  end

  def rw_test?(mount_info)
    mount_info.each do |pt|
      (Dir.exist? pt.split[0]) || (@crit_pt_test << "#{ pt.split[0] }")
      file = Tempfile.new('.sensu', pt.split[0])
      puts "The temp file we are writing to is: #{ file.path }" if config[:debug]
      #  need to add a check here to validate permissions, if none it pukes
      file.write('mops') || @crit_pt_test <<  "#{ pt.split[0] }"
      file.read || @crit_pt_test <<  "#{ pt.split[0] }"
      file.close
      file.unlink
    end
  end

  def filter_ignored!(mount_info)
    config[:ignore].each do |i|
      ignore = Regexp.escape(i)
      mount_info.reject! { |m| m.match(/^#{ignore}\W/) }
    end
  end

  def auto_discover
    mount_info = acquire_mnt_pts.split("\n")
    filter_ignored!(mount_info) if config[:ignore]
    ok 'No mount points found' if mount_info.length == 0
    # #YELLOW
    #  I want to map this at some point to make it pretty and eaiser to read for large filesystems
    puts 'This is a list of mount_pts and their current status: ', mount_info if config[:debug]
    rw_in_proc?(mount_info)
    rw_test?(mount_info)
    puts "The critical mount points according to proc are: #{ @crit_pt_proc }" if config[:debug]
    puts "The critical mount points according to actual testing are: #{ @crit_pt_test }" if config[:debug]
  end

  def manual_test
    config[:dir].each do |d|
      (Dir.exist? d) || (@crit_pt_test << "#{ d }")
      file = Tempfile.new('.sensu', d)
      puts "The temp file we are writing to is: #{ file.path }" if config[:debug]
      # #YELLOW
      #  need to add a check here to validate permissions, if none it pukes
      file.write('mops') || @crit_pt_test <<  "#{ d }"
      file.read || @crit_pt_test <<  "#{ d }"
      file.close
      file.unlink
    end
  end

  def run
    if config[:auto]
      auto_discover
    elsif config[:dir]
      manual_test
    else
      warning 'No directorties to check'
    end

    usage_summary
  end
end
