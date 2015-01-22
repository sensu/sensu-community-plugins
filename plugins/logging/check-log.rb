#! /usr/bin/env ruby
#
#   check-log
#
# DESCRIPTION:
#   This plugin checks a log file for a regular expression, skipping lines
#   that have already been read, like Nagios's check_log. However, instead
#   of making a backup copy of the whole log file (very slow with large
#   logs), it stores the number of bytes read, and seeks to that position
#   next time.
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: fileutils
#
# USAGE:
#   #YELLOW
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
require 'fileutils'

class CheckLog < Sensu::Plugin::Check::CLI
  BASE_DIR = '/var/cache/check-log'

  option :state_auto,
         description: 'Set state file dir automatically using name',
         short: '-n NAME',
         long: '--name NAME',
         proc: proc { |arg| "#{BASE_DIR}/#{arg}" }

  option :state_dir,
         description: 'Dir to keep state files under',
         short: '-s DIR',
         long: '--state-dir DIR',
         default: "#{BASE_DIR}/default"

  option :log_file,
         description: 'Path to log file',
         short: '-f FILE',
         long: '--log-file FILE'

  option :pattern,
         description: 'Pattern to search for',
         short: '-q PAT',
         long: '--pattern PAT'

  option :exclude,
         description: 'Pattern to exclude from matching',
         short: '-E PAT',
         long: '--exclude PAT',
         proc: proc { |s| Regexp.compile s },
         default: /(?!)/

  option :encoding,
         description: 'Explicit encoding page to read log file with',
         short: '-e ENCODING-PAGE',
         long: '--encoding ENCODING-PAGE'

  option :warn,
         description: 'Warning level if pattern has a group',
         short: '-w N',
         long: '--warn N',
         proc: proc(&:to_i)

  option :crit,
         description: 'Critical level if pattern has a group',
         short: '-c N',
         long: '--crit N',
         proc: proc(&:to_i)

  option :only_warn,
         description: 'Warn instead of critical on match',
         short: '-o',
         long: '--warn-only',
         boolean: true

  option :case_insensitive,
         description: 'Run a case insensitive match',
         short: '-i',
         long: '--icase',
         boolean: true,
         default: false

  option :file_pattern,
         description: 'Check a pattern of files, instead of one file',
         short: '-F FILE',
         long: '--filepattern FILE'

  option :return_content,
         description: 'Return matched line',
         short: '-r',
         long: '--return',
         boolean: true,
         default: false

  def run
    unknown 'No log file specified' unless config[:log_file] || config[:file_pattern]
    unknown 'No pattern specified' unless config[:pattern]
    file_list = []
    file_list << config[:log_file] if config[:log_file]
    if config[:file_pattern]
      dir_str = config[:file_pattern].slice(0, config[:file_pattern].to_s.rindex('/'))
      file_pat = config[:file_pattern].slice((config[:file_pattern].to_s.rindex('/') + 1), config[:file_pattern].length)
      Dir.foreach(dir_str) do |file|
        if config[:case_insensitive]
          file_list << "#{dir_str}/#{file}" if file.to_s.downcase.match(file_pat.downcase)
        else
          file_list << "#{dir_str}/#{file}" if file.to_s.match(file_pat)
        end
      end
    end
    n_warns_overall = 0
    n_crits_overall = 0
    error_overall = ''
    file_list.each do |log_file|
      begin
        open_log log_file
      rescue => e
        unknown "Could not open log file: #{e}"
      end
      n_warns, n_crits, accumulative_error = search_log
      n_warns_overall += n_warns
      n_crits_overall += n_crits

      if config[:return_content]
        error_overall = accumulative_error
      end
    end
    message "#{n_warns_overall} warnings, #{n_crits_overall} criticals for pattern #{config[:pattern]}. #{error_overall}"
    if n_crits_overall > 0
      critical
    elsif n_warns_overall > 0
      warning
    else
      ok
    end
  end

  def open_log(log_file)
    state_dir = config[:state_auto] || config[:state_dir]

    # Opens file using optional encoding page.  ex: 'iso8859-1'
    if config[:encoding]
      @log = File.open(log_file, "r:#{config[:encoding]}")
    else
      @log = File.open(log_file)
    end

    @state_file = File.join(state_dir, File.expand_path(log_file).sub(/^([A-Z]):\//, '\1/'))
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
    @bytes_to_skip = 0 if log_file_size < @bytes_to_skip
    bytes_read = 0
    n_warns = 0
    n_crits = 0
    accumulative_error = ''

    @log.seek(@bytes_to_skip, File::SEEK_SET) if @bytes_to_skip > 0
    # #YELLOW
    @log.each_line do |line| # rubocop:disable Style/Next
      bytes_read += line.size
      if config[:case_insensitive]
        m = line.downcase.match(config[:pattern].downcase) unless line.match(config[:exclude])
      else
        m = line.match(config[:pattern]) unless line.match(config[:exclude])
      end
      if m
        accumulative_error += "\n" + line.slice(0, 250)
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
    [n_warns, n_crits, accumulative_error]
  end
end
