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

class GlusterGeoReplStatus < Sensu::Plugin::Check::CLI

  option :states,
    :description => 'Comma delimited states (case sensitive)',
    :short => '-s STATE',
    :long => '--state STATE',
    :proc => lambda { |o| o.split(/[\s,]+/) },
    :required => true

  def run
    errors = Array.new
    `sudo gluster volume geo-replication status`.each_line do |l|
      # Don't match those lines or conditions.
      unless l =~ /(^geo-replication|^Another|^No active geo-replication sessions|^MASTER|^\s*$|^-)/
        unless config[:states].include?(l.split[4])
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
