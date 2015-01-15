#! /usr/bin/env ruby
#
#  check-journal
#
# DESCRIPTION:
#   This plugin checks the systemd journal (aka journald) for a pattern.
#   It is loosely based on the check-log.rb plugin and accepts similar arguments
#   where relevant.
#
#   Unlike check-log.rb or other file-based log checks, we do not need to keep state
#   since we can query the journal using hints such as `--since=-5minutes`. The check
#   interval and the `--since` argument should match in order to ensure adequate
#   and efficient coverage of the journal. See `journalctl(1)` man page for additional
#   details on valid values for the `--since` parameters.
#
#   Journalctl params
#   -----------------
#
#   By default, all available journal entries are queried. Any valid journalctl(1)
#   argument can be passed using `--journalctl_args="ARGS ..."`. For example, to
#   query only journal entries from the `elasticsearch.service` unit using the
#   `-u` option:
#
#      $ check-journal.rb --journalctl_args='-u elasticsearch.service' -q Error
#      CheckJournal CRITICAL: 20 matches found for Error in `journalctl --no-pager -a -u elasticsearch.service --since=-10minutes` (threshold 1)
#
#   Permissions
#   -----------
#
#   The user executing this script (probably the sensu user) must be a member of the
#   `systemd-journal` group to read all journal entries.
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
#   #YELLOW
#
# NOTES:
#
# LICENSE:
#   Copyright 2013 Joe Miller
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'

class CheckJournal < Sensu::Plugin::Check::CLI
  option :pattern,
         description: 'Pattern to search for',
         short: '-q PAT',
         long: '--pattern PAT'

  option :journalctl_args,
         description: 'Pass additional arguments to journalctl, eg: "-u nginx.service"',
         short: '-j "ARGS1 ARGS2 ..."',
         long: '--journalctl_args "ARGS1 ARGS2 ..."',
         default: ''

  option :since,
         description: 'Query journal entries on or newer than the specified date/time.',
         default: '-1minutes',
         short: '-s TIMESPEC',
         long: '--since TIMESPEC'

  option :warning_count,
         description: 'Number of matches to consider a warning',
         short: '-w COUNT',
         long: '--warning COUNT',
         default: 1,
         proc: proc(&:to_i)

  option :critical_count,
         description: 'Number of matches to consider a critical issue.',
         short: '-c COUNT',
         long: '--critical COUNT',
         default: 1,
         proc: proc(&:to_i)

  option :verbose,
         description: 'Verbose output. Helpful for debugging the plugin.',
         short: '-v',
         boolean: true,
         default: false

  def run
    unknown 'No pattern specified' unless config[:pattern]
    journalctl_args = '--no-pager -a ' + config[:journalctl_args] + " --since=#{config[:since]}"

    n_matches = search_journal(journalctl_args)

    message = "#{n_matches} matches found for #{config[:pattern]} in `journalctl #{journalctl_args}`"
    if n_matches >= config[:critical_count]
      critical message + " (threshold #{config[:critical_count]})"
    elsif n_matches >= config[:warning_count]
      warning message + " (threshold #{config[:warning_count]})"
    else
      ok message
    end
  end

  def search_journal(journalctl_args)
    n_matches = 0

    puts "Executing 'journalctl #{journalctl_args}'" if config[:verbose]
    IO.popen("journalctl #{journalctl_args}") do |cmd|
      cmd.each do |line|
        puts line if config[:verbose]
        n_matches += 1 if line.match(config[:pattern])
      end
    end
    n_matches
  end
end
