#!/usr/bin/env ruby
#
# Get the current unicorn queue count via raindrops
#   http://raindrops.bogomips.org/
# ===
#
# Created by Pete Shima - me@peteshima.com
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.
#

require "rubygems" if RUBY_VERSION < "1.9.0"
require 'sensu-plugin/metric/cli'
require "socket"
require "raindrops"


class UnicornMetrics < Sensu::Plugin::Metric::CLI::Graphite

  option :socket,
    :short => "-p SOCKETPATH",
    :long => "--path SOCKETPATH",
    :description => "Path to unicorn socket",
    :required => true

  option :scheme,
    :description => "Metric naming scheme, text to prepend to metric",
    :short => "-s SCHEME",
    :long => "--scheme SCHEME",
    :default => "#{Socket.gethostname}"

  def run
    addr = [ config[:socket] ]
    stats = Raindrops::Linux.unix_listener_stats(addr)
    queue = stats[config[:socket]][:queued]
    
    output "#{config[:scheme]}.unicorn.queued", queue

    ok
  end

end