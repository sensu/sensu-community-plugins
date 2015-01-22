#! /usr/bin/env ruby
#
#   check-disk
#
# DESCRIPTION:
#   Uses GNU's -T option for listing filesystem type; unfortunately, this
#   is not portable to BSD. Warning/critical levels are percentages only.
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#
# USAGE:
#
# NOTES:
#
# LICENSE:
#   Copyright 2011 Sonian, Inc <chefs@sonian.net>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'

class CheckDisk < Sensu::Plugin::Check::CLI
  option :fstype,
         short: '-t TYPE[,TYPE]',
         description: 'Only check fs type(s)',
         proc: proc { |a| a.split(',') }

  option :ignoretype,
         short: '-x TYPE[,TYPE]',
         description: 'Ignore fs type(s)',
         proc: proc { |a| a.split(',') }

  option :ignoremnt,
         short: '-i MNT[,MNT]',
         description: 'Ignore mount point(s)',
         proc: proc { |a| a.split(',') }

  option :ignoreline,
         short: '-l PATTERN[,PATTERN]',
         description: 'Ignore df line(s) matching pattern(s)',
         proc: proc { |a| a.split(',') }

  option :includeline,
         short: '-L PATTERN[,PATTERN]',
         description: 'Only include df line(s) matching pattern(s)',
         proc: proc { |a| a.split(',') }

  option :warn,
         short: '-w PERCENT',
         description: 'Warn if PERCENT or more of disk full',
         proc: proc(&:to_i),
         default: 85

  option :crit,
         short: '-c PERCENT',
         description: 'Critical if PERCENT or more of disk full',
         proc: proc(&:to_i),
         default: 95

  option :iwarn,
         short: '-W PERCENT',
         description: 'Warn if PERCENT or more of inodes used',
         proc: proc(&:to_i),
         default: 85

  option :icrit,
         short: '-K PERCENT',
         description: 'Critical if PERCENT or more of inodes used',
         proc: proc(&:to_i),
         default: 95

  option :debug,
         short: '-d',
         long: '--debug',
         description: 'Output list of included filesystems'

  def initialize
    super
    @crit_fs = []
    @warn_fs = []
    @line_count = 0
  end

  def read_df
    `df -lPT`.split("\n").drop(1).each do |line|
      begin
        _fs, type, _blocks, _used, _avail, capacity, mnt = line.split
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
      if capacity.to_i >= config[:crit]
        @crit_fs << "#{mnt} #{capacity}"
      elsif capacity.to_i >= config[:warn]
        @warn_fs <<  "#{mnt} #{capacity}"
      end
    end

    `df -lPTi`.split("\n").drop(1).each do |line|
      begin
        _fs, type, _inodes, _used, _avail, capacity, mnt = line.split
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
      if capacity.to_i > config[:icrit]
        @crit_fs << "#{mnt} inodes #{capacity}"
      elsif capacity.to_i >= config[:iwarn]
        @warn_fs << "#{mnt} inodes #{capacity}"
      end
    end
  end

  def usage_summary
    (@crit_fs + @warn_fs).join(', ')
  end

  def run
    unknown 'Do not use -l and -L options concurrently' if config[:includeline] && config[:ignoreline]
    read_df
    unknown 'No filesystems found' unless @line_count > 0
    critical usage_summary unless @crit_fs.empty?
    warning usage_summary unless @warn_fs.empty?
    ok "All disk usage under #{config[:warn]}% and inode usage under #{config[:iwarn]}%"
  end
end
