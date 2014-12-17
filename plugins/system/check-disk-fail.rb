#!/usr/bin/env ruby

#
# Check for failing disks
#
# Greps through dmesg output looking for
# indications that a drive is failing.
#
# All failures are reported as critical.
#
# Originally by Shane Feek, cleaned up by Alan Smith.
# Date: 07/14/2014
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'

class CheckDiskFail < Sensu::Plugin::Check::CLI
  def run
    dmesg = `dmesg`.lines

    %w(Read Write Smart).each do |v|
      found = dmesg.grep(/failed command\: #{v.upcase}/)
      # #YELLOW
      unless found.empty?  # rubocop:disable IfUnlessModifier
        critical "Disk #{v} Failure"
      end
    end

    ok
  end
end
