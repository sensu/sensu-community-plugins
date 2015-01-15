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
    total_ram, free_ram = 0, 0

    `free -m`.split("\n").drop(1).each do |line|
      # #YELLOW
      free_ram = line.split[3].to_i if line =~ /^-\/\+ buffers\/cache:/ # rubocop:disable RegexpLiteral
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
