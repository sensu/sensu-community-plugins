#! /usr/bin/env ruby
#
#   check-deleted-files
#
# DESCRIPTION:
#   Checks the number of deleted files held open by a command matching the
#   --command argument, using lsof.
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Linux, BSD
#
# DEPENDENCIES:
#   gem: sensu-plugin
#
# USAGE:
#   #YELLOW
#
# NOTES:
#
# LICENSE:
#   Copyright 2015 Squarespace
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'

class CheckDeletedFiles < Sensu::Plugin::Check::CLI
  option :command,
         short: '-m COMMAND',
         long: '--command COMMAND',
         description: 'The beginning of the command holding files',
         required: true

  option :critical,
         short: '-c CRITICAL_THRESHOLD',
         long: '--critical CRITICAL_THRESHOLD',
         description: 'Open deleted files equal to or above this is critical',
         default: 4,
         proc: proc(&:to_i)

  option :warning,
         short: '-w WARNING_THRESHOLD',
         long: '--warning WARNING_THRESHOLD',
         description: 'Open deleted files equal to or above this is a warning',
         default: 3,
         proc: proc(&:to_i)

  def run
    cmd = "/usr/sbin/lsof -nP | egrep '^#{config[:command]}.*(deleted)' | wc -l"
    output = `#{cmd}`.to_i
    msg = "#{config[:command]} is holding #{output} open files"

    if output >= config[:critical]
      critical msg
    elsif output >= config[:warning]
      warning msg
    else
      ok msg
    end
  end
end
