#! /usr/bin/env ruby
#
#   check-tail
#
# DESCRIPTION:
#   This plugin checks the tail of a file for a given patten and sends
#   critical (or optionally warning) message if found. Alternatively,
#   failure can be triggered when the pattern is not found by passing
#   the 'absent' flag.
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
#   Copyright 2014 Sonian, Inc. and contributors. <support@sensuapp.org>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'fileutils'

class Tail < Sensu::Plugin::Check::CLI
  option :file,
         description: 'Path to file',
         short: '-f FILE',
         long: '--file FILE'

  option :pattern,
         description: 'Pattern to search for',
         short: '-P PAT',
         long: '--pattern PAT'

  option :absent,
         description: 'Fail if pattern is absent',
         short: '-a',
         long: '--absent',
         boolean: true

  option :lines,
         description: 'Number of lines to tail',
         short: '-l LINES',
         long: '--lines LINES'

  option :warn_only,
         description: 'Warn instead of critical on match',
         short: '-w',
         long: '--warn-only',
         boolean: true

  def tail_file
    `tail #{config[:file]} -n #{config[:lines] || 1}`
  end

  def pattern_match?
    # #YELLOW
    !!tail_file.match(config[:pattern]) # rubocop:disable Style/DoubleNegation
  end

  def run
    unknown 'No log file specified' unless config[:file]
    unknown 'No pattern specified' unless config[:pattern]
    if File.exist?(config[:file])
      if !config[:absent]
        if pattern_match?
          send(
            # #YELLOW
            config[:warn_only] ? :warning : :critical,  # rubocop:disable BlockNesting
            "Pattern matched: #{config[:pattern]}"
          )
        else
          ok 'No matches found'
        end
      else
        if pattern_match?
          ok 'Match found'
        else
          send(
            # #YELLOW
            config[:warn_only] ? :warning : :critical, # rubocop:disable BlockNesting
            "Pattern not found: #{config[:pattern]}"
          )
        end
      end
    else
      critical 'File not found'
    end
  end
end
