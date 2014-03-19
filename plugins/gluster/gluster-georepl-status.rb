#!/usr/bin/env ruby
#
# Verifies Gluster's geo-replication status
# ===
#
# Jean-Francois Theroux <me@failshell.io>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'

class GlusterGeoreplStatus < Sensu::Plugin::Check::CLI
  def run
    errors = Array.new
    `gluster volume geo-replication status`.each_line do |l|
      # Need to remove the first 3 lines of the command's output
      unless l =~ /(^MASTER|^\s*$|^-)/
        unless l.split[4] =~ /(Active|Passive)/
          errors << "#{l.split[1]} on #{l.split[0]} is in #{l.split[4]} state"
        end
      end
    end

    if errors.empty?
      ok
    else
      critical errors
    end
  end
end
