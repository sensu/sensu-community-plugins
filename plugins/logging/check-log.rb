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
# Copyright 2011 Sonian, Inc <chefs@sonian.net>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'fileutils'

class CheckLog < Sensu::Plugin::Check::CLI

  BASE_DIR = '/var/cache/check-log'

  option :state_auto,
         :description => "Set state file dir automatically using name",
         :short => '-n NAME',
         :long => '--name NAME',
         :proc => proc {|arg| "#{BASE_DIR}/#{arg}" }

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

  option :warn,
         :description => "Warning level if pattern has a group",
         :short => '-w N',
         :long => '--warn N',
         :proc => proc {|a| a.to_i }

  option :crit,
         :description => "Critical level if pattern has a group",
         :short => '-c N',
         :long => '--crit N',
         :proc => proc {|a| a.to_i }

  option :only_warn,
         :description => "Warn instead of critical on match",
         :short => '-o',
         :long => '--warn-only',
         :boolean => true

  def run
    unknown "No log file specified" unless config[:log_file]
    unknown "No pattern specified" unless config[:pattern]
    begin
      open_log
    rescue => e
      unknown "Could not open log file: #{e}"
    end
    n_warns, n_crits = search_log
    message "#{n_warns} warnings, #{n_crits} criticals"
    if n_crits > 0
      critical
    elsif n_warns > 0
      warning
    else
      ok
    end
  end

  def open_log
    state_dir = config[:state_auto] || config[:state_dir]
    @log = File.open(config[:log_file])
    @state_file = File.join(state_dir, File.expand_path(config[:log_file]))
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
    n_warns = 0
    n_crits = 0
    if @bytes_to_skip > 0
      @log.seek(@bytes_to_skip, File::SEEK_SET)
    end
    @log.each_line do |line|
      bytes_read += line.size
      if m = line.match(config[:pattern])
        if m[1]
          if config[:crit] && m[1].to_i > config[:crit]
            n_crits += 1
          elsif config[:warn] && m[1].to_i > config[:warn]
            n_warns += 1
          end
        else
          if config[:only_warn]
            n_warns += 1
          else
            n_crits += 1
          end
        end
      end
    end
    FileUtils.mkdir_p(File.dirname(@state_file))
    File.open(@state_file, 'w') do |file|
      file.write(@bytes_to_skip + bytes_read)
    end
    [n_warns, n_crits]
  end

end
