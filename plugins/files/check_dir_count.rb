#!/usr/bin/env ruby
#
# Checks the number of files in a directory
# ===
#
# DESCRIPTION:
#   This plugin checks the number of files in a directory
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

class DirCount < Sensu::Plugin::Check::CLI

  option :directory,
    :description => 'Directory to count files in',
    :short => '-d DIR',
    :long => '--dir DIR',
    :required => true

  option :warning_num,
    :description => 'Warn if count of files is greater than provided number',
    :short => '-w NUM',
    :long => '--warning NUM',
    :required => true

  option :critical_num,
    :description => 'Critical if count of files is greater than provided number',
    :short => '-c NUM',
    :long => '--critical NUM',
    :required => true

  def run
    begin
      # Subtract two for '.' and '..'
      num_files = Dir.entries(config[:directory]).count - 2
    rescue
      unknown "Error listing files in #{config[:directory]}"
    end

    if num_files >= config[:critical_num].to_i
      critical "#{config[:directory]} has #{num_files} files (threshold: #{config[:critical_num]})"
    elsif num_files >= config[:warning_num].to_i
      warning "#{config[:directory]} has #{num_files} files (threshold: #{config[:warning_num]})"
    else
      ok "#{config[:directory]} has #{num_files} files"
    end
  end
end
