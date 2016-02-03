#! /usr/bin/env ruby
#  encoding: UTF-8
#
#   check-ram
#
# DESCRIPTION:
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
#   Copyright 2012 Sonian, Inc <chefs@sonian.net>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#
require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'

class CheckRAM < Sensu::Plugin::Check::CLI
  option :megabytes,
         short: '-m',
         long: '--megabytes',
         description: 'Unless --megabytes is specified the thresholds are in percents',
         boolean: true,
         default: false

  option :warn,
         short: '-w WARN',
         proc: proc(&:to_i),
         default: 10

  option :crit,
         short: '-c CRIT',
         proc: proc(&:to_i),
         default: 5

  def run
    memhash = {}
    meminfo = File.read('/proc/meminfo')
    meminfo.each_line do |i|
      key, val = i.split(':')
      val = val.include?('kB') ? val.gsub(/\s+kB/, '') : val
      memhash["#{key}"] = val.strip
    end

    total_ram = (memhash['MemTotal'].to_i << 10) >> 20
    if memhash.key?('MemAvailable')
      free_ram = (memhash['MemAvailable'].to_i << 10) >> 20
    else
      free_ram = ((memhash['MemFree'].to_i + memhash['Buffers'].to_i + memhash['Cached'].to_i) << 10) >> 20
    end

    if config[:megabytes]
      message "#{free_ram} megabytes free RAM left"

      critical if free_ram < config[:crit]
      warning if free_ram < config[:warn]
      ok
    else
      unknown 'invalid percentage' if config[:crit] > 100 || config[:warn] > 100

      percents_left = free_ram * 100 / total_ram
      message "#{percents_left}% free RAM left"

      critical if percents_left < config[:crit]
      warning if percents_left < config[:warn]
      ok
    end
  end
end
