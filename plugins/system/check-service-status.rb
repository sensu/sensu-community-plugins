#!/usr/bin/env ruby
#
# Check service status
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'

class CheckServiceStatus < Sensu::Plugin::Check::CLI
  option :service,
         short: '-s service',
         proc: proc { |a| a.to_s },
         required: true

  def run
    begin
      output = `status #{config[:service]}`
    rescue
      unknown "Service #{config[:service]} unknown"
    end

    output.each_line do |line|
      if line =~ /start\/running/
        ok(line)
      elsif line =~ /stop\/waiting/
        critical(line)
      else
        warning(line)
      end
    end
  end
end
