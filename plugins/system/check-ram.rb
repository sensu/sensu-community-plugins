#!/usr/bin/env ruby
#
# Check free RAM Plugin
# ===
#
# DESCRIPTION:
# This plugin checks the free ram left in the server.
#
# OUTPUT:
#   plain-text
#
# PLATFORMS:
#   all
#
# USAGE:
#   ./check-ram.rb -w 15 -c 5  (Warn if 85% of RAM is used and Crit if 95% is used)
#   ./check-ram.rb -m -w 1024 -c 512  (Warn if only 1GB of RAM is left and Crit if 512M is left)
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
    total_ram, free_ram = 0, 0

    `free -m`.split("\n").drop(1).each do |line|
      free_ram = line.split[3].to_i if line =~ %r{^-/\+ buffers/cache:}
      total_ram = line.split[1].to_i if line =~ /^Mem:/
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
