#! /usr/bin/env ruby
#  encoding: UTF-8
#
#   conntrack-metrics
#
# DESCRIPTION:
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
#
# NOTES:
#
# LICENSE:
#   Copyright 2012 Sonian, Inc <chefs@sonian.net>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/metric/cli'
require 'socket'

class Conntrack < Sensu::Plugin::Metric::CLI::Graphite
  option :scheme,
         description: 'Metric naming scheme, text to prepend to .$parent.$child',
         long: '--scheme SCHEME',
         default: "#{Socket.gethostname}.conntrack.connections"

  option :table,
         description: 'Table to count',
         long: '--table TABLE',
         default: 'conntrack'

  def run
    value = `conntrack -C #{config[:table]}`.strip
    timestamp = Time.now.to_i

    output config[:scheme], value, timestamp

    ok
  end
end
