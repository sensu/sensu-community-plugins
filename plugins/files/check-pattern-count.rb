#!/usr/bin/env ruby
#
# Check Pattern Count
# ===
#
# Counts the number of files matching a shell pattern, raising a 'warning' or
# 'critical' message if the count is above the thesholds supplied using -w
# and -c respectively.
#
# If testing this check from the command line, it may be necessary to quote
# the file patterns.
#
# Examples:
#
#   # count files with 'error' file extension
#   check-pattern-count.rb -p '*.error' -w 1 -c 10
#
#   # count files across all subdirectories
#   check-pattern-count.rb -p '*/*' -w 1 -c 10
#
# Copyright 2014 Aaron Iles <aaron.iles@gmail.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.
require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'fileutils'

class PatternCount < Sensu::Plugin::Check::CLI

  option :pattern,
    :description => 'Shell pattern to match files against',
    :short => '-p PATTERN',
    :long => '--pattern PATTERN',
    :required => true

  option :warning_num,
    :description => 'Warn if count of files is greater than provided number',
    :short => '-w NUM',
    :long => '--warning NUM',
    :required => true

  option :critical_num,
    :description => 'Critical if count of files is greater than provided number',
    :short => '-c NUM',
    :long => '--critical NUM',
    :required => true

  def run
    begin
      num_files = Dir.glob(config[:pattern]).count
    rescue
      unknown "Error matching files using #{config[:pattern]}"
    end

    if num_files >= config[:critical_num].to_i
      critical "'#{config[:pattern]}' matches #{num_files} files (threshold: #{config[:critical_num]})"
    elsif num_files >= config[:warning_num].to_i
      warning "'#{config[:pattern]}' matches #{num_files} files (threshold: #{config[:warning_num]})"
    else
      ok "'#{config[:pattern]}' matches #{num_files} files"
    end
  end
end
