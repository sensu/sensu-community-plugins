#! /usr/bin/env ruby
#
# Check Inode Usage
# ===
#
# DESCRIPTION:
#   This plugin provides a method for monitoring the inode usage.  It will alert on the percentage used.  This is a port of the sensu community plugin 'check-disk', all I did was change df to use inodes.
#
# OUTPUT:
#   plain-text
#
# PLATFORMS:
#   all
#
# DEPENDENCIES:
#
# Copyright 2014 Yieldbot, Inc  <devops@yieldbot.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'

class CheckInode < Sensu::Plugin::Check::CLI

  option :fstype,
    :short => '-t TYPE',
    :proc => proc {|a| a.split(',') }

  option :ignoretype,
    :short => '-x TYPE',
    :proc => proc {|a| a.split(',') }

  option :ignoremnt,
    :short => '-i MNT',
    :proc => proc {|a| a.split(',') }

  option :ignoreline,
    :short => '-l PATTERN[,PATTERN]',
    :description => 'Ignore df line(s) matching pattern(s)',
    :proc => proc { |a| a.split(',') }

  option :includeline,
    :short => '-L PATTERN[,PATTERN]',
    :description => 'Only include df line(s) matching pattern(s)',
    :proc => proc { |a| a.split(',') }

  option :warn,
    :short => '-w PERCENT',
    :proc => proc {|a| a.to_i },
    :default => 80

  option :crit,
    :short => '-c PERCENT',
    :proc => proc {|a| a.to_i },
    :default => 90

  option :debug,
      :short => '-d',
      :long => '--debug',
      :description => 'Output list of included filesystems'

  def initialize
    super
    @crit_fs = []
    @warn_fs = []
    @line_count = 0
  end

  def read_inode_pct
    `df -iPT`.split("\n").drop(1).each do |line|
      begin
        _fs, type, _blocks, _used, _avail, inode_usage, mnt = line.split
        next if config[:includeline] && !config[:includeline].find { |x| line.match(x) }
        next if config[:fstype] && !config[:fstype].include?(type)
        next if config[:ignoretype] && config[:ignoretype].include?(type)
        next if config[:ignoremnt] && config[:ignoremnt].include?(mnt)
        next if config[:ignoreline] && config[:ignoreline].find { |x| line.match(x) }
        puts line if config[:debug]
      rescue
        unknown "malformed line from df: #{line}"
      end
      @line_count += 1
      if inode_usage.to_i >= config[:crit]
        @crit_fs << "#{mnt} #{capacity}"
      elsif inode_usage.to_i >= config[:warn]
        @warn_fs <<  "#{mnt} #{capacity}"
      end
    end
  end

  def usage_summary
    (@crit_fs + @warn_fs).join(', ')
  end

  def run
    if config[:includeline] && config[:ignoreline]
      unknown 'Do not use -l and -L options concurrently'
    end
    read_inode_pct
    unknown 'No filesystems found' unless @line_count > 0
    critical usage_summary unless @crit_fs.empty?
    warning usage_summary unless @warn_fs.empty?
    ok "All inode usage under #{config[:warn]}%"
  end

end
