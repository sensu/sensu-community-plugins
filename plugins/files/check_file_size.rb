#!/usr/bin/env ruby
#
# Author: AJ Bourg <aj@ajbourg.com>
#
# Checks to ensure a file is no larger than a specified size.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'

class CheckMailDelivery < Sensu::Plugin::Check::CLI
  option :critical_size,
    :short => '-c SIZE',
    :long => '--critical SIZE',
    :proc => proc {|a| a.to_i },
    :description => "Max size in bytes for critical."
  option :nonexist,
    :short => '-n',
    :boolean => true
    :description => "It's ok if the file doesn't exist."
  option :critical_size,
    :short => '-w SIZE',
    :long => '--warning SIZE',
    :proc => proc {|a| a.to_i },
    :description => "Max size in bytes for warning."
  option :file,
    :short => '-f FILE',
    :long => '--file FILE',
    :description => "The file to check."
    
  def run
    # sorry this is confusing
    if not File.file?(config[:file]) and config[:nonexist]
      ok "Not a file."
    elsif not File.file?(config[:file]) and not config[:nonexist]
      warning "Not a file."
    end
    
    size = File.size(config[:file])
    
    if size >= config[:critical_size]
      critical "File is #{size} bytes!"
    elsif size >= config[:warning_size]
      warning "File is #{size} bytes!"
    else
      ok "File is #{size} bytes!"
    end
  end
end