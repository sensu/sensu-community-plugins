#!/usr/bin/env ruby
require 'rubygems' if RUBY_VERSION < '1.9.0'
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
