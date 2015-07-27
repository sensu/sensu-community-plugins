#! /usr/bin/env ruby
#
#   check-dir-size
#
# DESCRIPTION:
#   Checks the size of a directory using 'du'
#   Optional command line parameter to ignore a missing directory
#
#   WARNING: When using this with a directory with a lot of files, there will be
#            some lag as 'du' recursively goes through the directory
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Linux, BSD
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   binary: du (default location: /usr/bin/du, alternate location can be set)
#
# USAGE:
#   check-dir-size.rb [-d|--directory] </path/to/directory>
#                     [-w|--warn] <size, in bytes, to warn on>
#                     [-c|--critical] <size, in bytes, to go CRITICAL on>
#                     [-p|--du-path] <path/to/du>
#                     [--ignore_missing]
#
# EXAMPLE:
#   check-dir-size.rb /var/spool/example_dir -w 1500000 -c 2000000
#     This will warn at 1.5MB and go critical at 2.0MB for /var/spool/example_dir
#
# LICENSE:
#   Copyright 2015 Jayson Sperling (jayson.sperling@sendgrid.com)
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#
require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'

class CheckDirSize < Sensu::Plugin::Check::CLI

  option :directory,
    description: 'Directory to stat (full path not including trailing slash)',
    short: '-d /path/to/directory',
    long: '--directory /path/to/directory',
    required: true

  option :warn,
    description: 'The size (in bytes) of the directory where WARNING is raised',
    short: '-w SIZE_IN_BYTES',
    long: '--warn SIZE_IN_BYTES',
    default: 3_500_000,
    required: false

  option :crit,
    description: 'The size (in bytes) of the directory where CRITICAL is raised',
    short: '-c SIZE_IN_BYTES',
    long: '--critical SIZE_IN_BYTES',
    default: 4_000_000,
    required: false

  option :ignore_missing,
    description: 'Do not throw CRITICAL if the directory is missing',
    long: '--ignore-missing',
    boolean: true,
    default: false,
    required: false

  option :du_path,
    description: 'The path to the `du` command',
    long: '--du-path /path/to/du',
    short: '-p /path/to/du',
    default: '/usr/bin/du',
    required: false

  # Even though most everything should have 'du' installed by default, let's do a quick sanity check
  def check_external_dependency
    critical "This system does not have 'du' at #{config[:du_path]}!" unless File.exists? config[:du_path]
  end

  def du_directory
    if Dir.exists? config[:directory]
      cmd = "#{config[:du_path]} #{config[:directory]} --bytes --summarize | /usr/bin/awk '{ printf \"%s\",$1 }'"
      @dir_size = `#{cmd}`
    else
      if config[:ignore_missing] == true
        ok "Directory #{config[:directory]} does not exist (--ignore-missing was set)"
      else
        critical "Directory #{config[:directory]} does not exist!"
      end
    end
  end

  def compare_size
    if @dir_size.to_i >= config[:crit].to_i
      critical "Directory #{config[:directory]} is greater than #{format_bytes(config[:crit].to_i)} bytes [actual size: #{format_bytes(@dir_size.to_i)} bytes]"
    elsif @dir_size.to_i >= config[:warn].to_i
      warning "Directory #{config[:directory]} is greater than #{format_bytes(config[:warn].to_i)} bytes [actual size: #{format_bytes(@dir_size.to_i)} bytes]"
    else
      ok "Directory #{config[:directory]} is within size limit"
    end
  end

  def run
    check_external_dependency
    du_directory
    compare_size
  end

  # Helper functions
  def format_bytes(number)
    number.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
  end

end
