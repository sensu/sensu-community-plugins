#!/usr/bin/env ruby
#
# Check fstab Mounts Plugin
# ===
#
# Check /proc/mounts to ensure all filesystems of the requested type(s) from
# fstab are currently mounted.  If no fstypes are specified, will check all
# entries in fstab.
#
# Peter Fern <ruby@0xc0dedbad.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'pathname'

class CheckFstabMounts < Sensu::Plugin::Check::CLI
  option :fstypes,
    :description => 'Filesystem types to check, comma-separated',
    :short => '-t TYPES',
    :long => '--types TYPES',
    :proc => proc {|a| a.split(',')},
    :required => false

  def initialize
    super
    @fstab = IO.readlines '/etc/fstab'
    @proc_mounts = IO.readlines '/proc/mounts'
    @swap_mounts = IO.readlines '/proc/swaps'
    @missing_mounts = []
  end

  def check_mounts
    # check by mount destination, which is col 2 in fstab and proc/mounts
    @fstab.each do |line|
      next if line =~ /^\s*#/
      fields = line.split(/\s+/)
      next if fields[1] == 'none' || (fields[3].include? 'noauto')
      next if config[:fstypes] && !config[:fstypes].include?(fields[2])
      if fields[2] != 'swap'
        if @proc_mounts.select {|m| m.split(/\s+/)[1] == fields[1]}.empty?
          @missing_mounts << fields[1]
        end
      else
        if @swap_mounts.select {|m| m.split(/\s+/)[0] == Pathname.new(fields[0]).realpath.to_s}.empty?
          @missing_mounts << fields[1]
        end
      end
    end
  end

  def run
    check_mounts
    if @missing_mounts.any?
      critical "Mountpoint(s) #{@missing_mounts.join(',')} not mounted!"
    else
      ok 'All mountpoints accounted for'
    end
  end
end
