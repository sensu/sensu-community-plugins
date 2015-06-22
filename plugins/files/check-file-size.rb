#! /usr/bin/env ruby
#
#   check-file-size
#
# DESCRIPTION:
#   Checks the file size of a given file.
#   Optional command line parameters to ignore missing files
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
#   check-file-size.rb --file <filename>
#                      [--warn <size, in bytes, to warn on>]
#                      [--critical <size, in bytes, to go CRITICAL on>]
#                      [--ignore_missing]
#                      [--debug]
#
# LICENSE:
#   Copyright 2015 Jayson Sperling (jayson.sperling@sendgrid.com)
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#
require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'

class CheckFileSize < Sensu::Plugin::Check::CLI
  attr_accessor :file_size

  option :file,
         description: 'file to stat (full path)',
         short: '-f',
         long: '--file FILENAME',
         required: true

  option :warn,
         description: 'The size (in bytes) of the file where WARNING is raised',
         short: '-w SIZE',
         long: '--warn SIZE',
         proc: proc(&:to_i),
         default: 2_000_000

  option :crit,
         description: 'The size (in bytes) of the file where CRITICAL is raised',
         short: '-c SIZE',
         long: '--critical SIZE',
         proc: proc(&:to_i),
         default: 3_000_000

  option :ignore_missing,
         short: '-i',
         long: '--ignore-missing',
         description: 'Do not throw CRITICAL if the file is missing',
         boolean: true,
         default: false

  option :debug,
         short: '-d',
         long: '--debug',
         description: 'Output list of included filesystems',
         boolean: true,
         default: false

  def stat_file
    if File.exist? config[:file]
      stat = File.stat(config[:file])
      $stdout.puts stat.inspect if config[:debug] == true
      @file_size = stat.size
    else
      if config[:ignore_missing] == true
        ok "#{config[:file]} does not exist (--ignore-missing was set)"
      else
        critical "#{config[:file]} does not exist"
      end
    end
  end

  def compare_size
    if @file_size >= config[:crit].to_i
      critical "#{config[:file]} is greater than #{format_bytes(config[:crit])} bytes! [actual size: #{format_bytes(@file_size)} bytes]"
    elsif @file_size >= config[:warn]
      warning "#{config[:file]} is greater than #{format_bytes(config[:warn])} bytes! [actual size: #{format_bytes(@file_size)} bytes]"
    else
      ok "#{config[:file]} is within size limit"
    end
  end

  def run
    stat_file
    compare_size
  end

  def format_bytes(number)
    number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end
end
