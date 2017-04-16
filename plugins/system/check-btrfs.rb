#!/usr/bin/env ruby
#
# Check BTRFS Plugin
# ===
#
# Uses `btrfs fi show` to check device usage.
# BTRFS devices can become full before the `df` usage indicates the filesystem is full.
# Devices close to full need to be balanced with `btrfs balance start -dusage=USAGE_PERCENT`
# See. http://marc.merlins.org/perso/btrfs/post_2014-05-04_Fixing-Btrfs-Filesystem-Full-Problems.html
#
# This check may not work correctly for filesystems with multiple devices.
# Can probably be extended to perform other checks such as last scrub and its results.
#
# Example sudoers entry
# sensu ALL=(root) NOPASSWD:/usr/sbin/btrfs fi show
#
# Copyright 2014 Tim Robinson <tim@voltgrid.com>
#
# Released under the MIT License
require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'

class CheckBtrfs < Sensu::Plugin::Check::CLI
  option :warn,
    short: '-w PERCENT',
    description: 'Warn if PERCENT or more of device full',
    proc: proc { |a| a.to_i },
    default: 85

  option :crit,
    short: '-c PERCENT',
    description: 'Critical if PERCENT or more of device full',
    proc: proc { |a| a.to_i },
    default: 95

  option :debug,
    short: '-d',
    long: '--debug',
    description: 'Output debug'

  def initialize
    super
    @crit_dev = []
    @warn_dev = []
    @line_count = 0
  end

  def read_fi
    `sudo btrfs fi show`.split("\n").each do |line|
      begin
        match = line.match(/devid\s+\d+\s+size\s+(\d+([\d\.]+)?)GiB\s+used\s+(\d+([\d\.]+)?)GiB\s+path\s+([\w\/]+)/)
        next unless match
        size = match[1].to_f
        used = match[3].to_f
        dev = match[5]
        percent = used / size * 100
      rescue
        unknown 'Bad btrfs fi show output'
      end
      @line_count += 1
      puts "#{dev}: #{'%.2f' % percent}% used #{used} size #{size}" if config[:debug]
      if percent >= config[:crit]
        @crit_dev << "#{dev} #{'%.2f' % percent}%"
      elsif percent >= config[:warn]
        @warn_dev << "#{dev} #{'%.2f' % percent}%"
      end
    end
  end

  def usage_summary
    (@crit_dev + @warn_dev).join(', ')
  end

  def run
    read_fi
    unknown 'No devices found' unless @line_count > 0
    critical usage_summary unless @crit_dev.empty?
    warning usage_summary unless @warn_dev.empty?
    ok "All devices usage under #{config[:warn]}%"
  end
end
