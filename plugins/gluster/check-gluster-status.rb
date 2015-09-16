#! /usr/bin/env ruby
#
#   check-guster-status
#
# DESCRIPTION:
#   Verifies Gluster's volume replication status#
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
#   Samuel Terburg <samuel.terburg@panther-it.nl>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'

class GlusterReplStatus < Sensu::Plugin::Check::CLI
  option :ignore_nfs,
         short: '-n',
         long: '--ignore-nfs',
         description: 'Ignore builtin NFS server',
         boolean: true,
         default: false

  option :ignore_selfheal,
         short: '-s',
         long: '--ignore-selfheal',
         description: 'Ignore selfheal service',
         boolean: true,
         default: false
  
  def run
    errors = []
    # #YELLOW
    `sudo gluster volume status`.each_line do |l| # rubocop:disable Style/Next
      # Don't match those lines or conditions.
      if l =~ / N /
        unless (config[:ignore_nfs]      and 'NFS'.include?(l.split[0])) \
            or (config[:ignore_selfheal] and 'Self-heal'.include?(l.split[0]))
          errors << "#{l.split[0]} #{l.split[1]} is DOWN"
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
