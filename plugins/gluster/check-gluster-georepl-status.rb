#! /usr/bin/env ruby
#
#   check-guster-georepl-status
#
# DESCRIPTION:
#   Verifies Gluster's geo-replication status#
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#
# USAGE:
#   #YELLOW
#
# NOTES:
#
# LICENSE:
#   Jean-Francois Theroux <me@failshell.io>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'

class GlusterGeoReplStatus < Sensu::Plugin::Check::CLI
  option :states,
         description: 'Comma delimited states (case sensitive)',
         short: '-s STATE',
         long: '--state STATE',
         # #YELLOW
         proc: lambda { |o| o.split(/[\s,]+/) }, # rubocop:disable Lambda
         required: true

  def run
    errors = []
    # #YELLOW
    `sudo gluster volume geo-replication status`.each_line do |l| # rubocop:disable Style/Next
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
