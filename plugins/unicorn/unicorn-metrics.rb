#!/usr/bin/env ruby
#
# Pull unicorn metrics
# ===
#
require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'raindrops'

class UnicornMetrics < Sensu::Plugin::Metric::CLI::Graphite
  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         default: "#{Socket.gethostname}.unicorn"

  option :socket,
         description: 'Unicorn socket path',
         short: '-p SOCKET',
         long: '--socket-path SOCKET',
         default: '/tmp/unicorn.sock'

  def run
    stats = Raindrops::Linux.unix_listener_stats([config[:socket]])[config[:socket]]

    output "#{config[:scheme]}.active", stats.active
    output "#{config[:scheme]}.queued", stats.queued
    ok
  end
end
