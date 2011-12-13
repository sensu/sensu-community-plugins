#!/usr/bin/env ruby
#
# Check Log Plugin
# ===
#
# This plugin checks a log file for a regular expression, skipping lines
# that have already been read, like Nagios's check_log. However, instead
# of making a backup copy of the whole log file (very slow with large
# logs), it stores the number of bytes read, and seeks to that position
# next time.
#
# Copyright 2011 Sonian, Inc.
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'sensu-plugin/check/cli'
require 'fileutils'

class CheckLog < Sensu::Plugin::Check::CLI

  BASE_DIR = '/var/cache/check_log'

  option :state_dir,
         :description => "Dir to keep state files under",
         :short => '-s DIR',
         :long => '--state-dir DIR',
         :default => "#{BASE_DIR}/default"

  option :log_file,
         :description => "Path to log file",
         :short => '-f FILE',
         :long => '--log-file FILE'

  option :pattern,
         :description => "Pattern to search for",
         :short => '-q PAT',
         :long => '--pattern PAT'

  option :warn_only,
         :description => "Warn instead of critical on match",
         :short => '-w',
         :long => '--warn-only',
         :boolean => true

  def run
    unknown "No log file specified" unless config[:log_file]
    unknown "No pattern specified" unless config[:pattern]
    open_log
    n_matches = search_log
    if n_matches == 0
      ok "No matches"
    else
      if config[:warn_only]
        warning "#{n_matches} matches found"
      else
        critical "#{n_matches} matches found"
      end
    end
  end

  def open_log
    @log = File.open(config[:log_file])
    @state_file = File.join(config[:state_dir], File.expand_path(config[:log_file]))
    @bytes_to_skip = begin
      File.open(@state_file) do |file|
        file.readline.to_i
      end
    rescue
      0
    end
  end

  def search_log
    log_file_size = @log.stat.size
    if log_file_size < @bytes_to_skip
      @bytes_to_skip = 0
    end
    bytes_read = 0
    n_matches = 0
    if @bytes_to_skip > 0
      @log.seek(@bytes_to_skip, File::SEEK_SET)
    end
    @log.each_line do |line|
      bytes_read += line.size
      if line.match(config[:pattern])
        n_matches += 1
      end
    end
    FileUtils.mkdir_p(File.dirname(@state_file))
    File.open(@state_file, 'w') do |file|
      file.write(@bytes_to_skip + bytes_read)
    end
    n_matches
  end

end
