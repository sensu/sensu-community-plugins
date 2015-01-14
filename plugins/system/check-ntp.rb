#! /usr/bin/env ruby
#
#   check-ntp
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
#  warning and critical values are offsets in milliseconds.
#
# LICENSE:
#   Copyright 2012 Sonian, Inc <chefs@sonian.net>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'

class CheckNTP < Sensu::Plugin::Check::CLI
  option :warn,
         short: '-w WARN',
         proc: proc(&:to_i),
         default: 10

  option :crit,
         short: '-c CRIT',
         proc: proc(&:to_i),
         default: 100

  def run
    begin
      offset = `ntpq -c "rv 0 offset"`.split('=')[1].strip.to_f
    rescue
      unknown 'NTP command Failed'
    end

    critical if offset >= config[:crit] || offset <= -config[:crit]
    warning if offset >= config[:warn] || offset <= -config[:warn]
    ok
  end
end
