#!/usr/bin/env ruby
#
# Check Windows Disk Plugin
# ===
#
# This is mostly copied from the original check-disk.rb plugin and modified
# to use WMIC.  This is our first attempt at writing a plugin for Windows.
#
# Uses Windows WMIC facility. Warning/critical levels are percentages only.
#
# REQUIRES: ActiveSupport version 4.0 or above.
#
# Copyright 2013 <bp-parks@wiu.edu> <mr-mencel@wiu.edu>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.
# rubocop:disable VariableName

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'active_support/core_ext/numeric'

class CheckDisk < Sensu::Plugin::Check::CLI

    option :fstype,
        :short => '-t TYPE',
        :proc => proc {|a| a.split(',') }

    option :ignoretype,
        :short => '-x TYPE',
        :proc => proc {|a| a.split(',') }

    option :ignoremnt,
        :short => '-i MNT',
        :proc => proc {|a| a.split(',') }

    option :warn,
        :short => '-w PERCENT',
        :proc => proc {|a| a.to_i },
        :default => 85

    option :crit,
        :short => '-c PERCENT',
        :proc => proc {|a| a.to_i },
        :default => 95

    def initialize
        super
        @crit_fs = []
        @warn_fs = []
    end

    def read_wmic
        `wmic volume list brief`.split("\n").drop(1).each do |line|
            begin
                capacity, type, _fs, _avail, label, mnt = line.split
                next if /\S/ !~ line
                next if _avail.nil?
                next if line.include?("System Reserved")
                next if config[:fstype] && !config[:fstype].include?(type)
                next if config[:ignoretype] && config[:ignoretype].include?(type)
                next if config[:ignoremnt] && config[:ignoremnt].include?(mnt)
            rescue
                unknown "malformed line from df: #{line}"
            end
            # If label value is not set, the drive letter will end up in that column.  Set mnt to label in that case.
            mnt = label if mnt.nil?
            prct_used = (100*(1-(_avail.to_f / capacity.to_f)))
            if prct_used >= config[:crit]
                @crit_fs << "#{mnt} #{prct_used.to_s(:percentage, precision: 0)}"
            elsif prct_used >= config[:warn]
                @warn_fs << "#{mnt} #{prct_used.to_s(:percentage, precision: 0)}"
            end
        end
    end

    def usage_summary
        (@crit_fs + @warn_fs).join(', ')
    end

    def run
        read_wmic
        critical usage_summary unless @crit_fs.empty?
        warning usage_summary unless @warn_fs.empty?
        ok "All disk usage under #{config[:warn]}%"
    end

end
