#!/usr/bin/env ruby
#
# Checks a file's mtime
# ===
#
# DESCRIPTION:
#   This plugin checks a given file's modified time.
#
# OUTPUT:
#   plain-text
#
# PLATFORMS:
#   linux
#   bsd
#
# DEPENDENCIES:
#   sensu-plugin Ruby gem
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'fileutils'

class Mtime < Sensu::Plugin::Check::CLI

  option :file,
    :description => 'File to check last modified time',
    :short => '-f FILE',
    :long => '--file FILE'

  option :warning_age,
    :description => 'Warn if mtime greater than provided age in seconds',
    :short => '-w SECONDS',
    :long => '--warning SECONDS'

  option :critical_age,
    :description => 'Critical if mtime greater than provided age in seconds',
    :short => '-c SECONDS',
    :long => '--critical SECONDS'

  option :ok_no_exist,
    :description => 'OK if file does not exist',
    :short => '-o',
    :long => '--ok-no-exist',
    :boolean => true,
    :default => false

  def run_check(type, age)
    to_check = config["#{type}_age".to_sym].to_i
    if to_check > 0 && age >= to_check
      send(type, "file is #{age - to_check} seconds past #{type}")
    end
  end

  def run
    unknown 'No file specified' unless config[:file]
    unknown 'No warn or critical age specified' unless config[:warning_age] || config[:critical_age]
    if File.exists?(config[:file])
      age = Time.now.to_i - File.mtime(config[:file]).to_i
      run_check(:critical, age) || run_check(:warning, age) || ok("file is #{age} seconds old")
    else
      if config[:ok_no_exist]
        ok 'file does not exist'
      else
        critical 'file not found'
      end
    end
  end

end
