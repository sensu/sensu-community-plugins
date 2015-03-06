#! /usr/bin/env ruby
#
#   check-entrophy
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
#   Copyright 2011 Sonian, Inc <chefs@sonian.net>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'

class CheckEntropy < Sensu::Plugin::Check::CLI
  option :warn,
         short: '-w WARN',
         proc: proc(&:to_i),
         default: 60

  option :crit,
         short: '-c CRIT',
         proc: proc(&:to_i),
         default: 30

  def run
    unknown 'invalid entropy treshold' if config[:crit] < 0 || config[:warn] < 0

    entropy = 0

    File.open('/proc/sys/kernel/random/entropy_avail', 'r').each_line do |line|
      entropy = line.strip.split(/\s+/).shift.to_i
    end

    critical if entropy < config[:crit]
    warning if entropy < config[:warn]
    ok
  end
end
