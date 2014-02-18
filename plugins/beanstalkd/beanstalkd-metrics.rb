#!/usr/bin/env ruby
#
# Pull beanstalkd metrics
# ===
#
# DESCRIPTION:
#   This plugin checks the beanstalkd stats, using the beaneater gem
#
# DEPENDENCIES:
#   sensu-plugin Ruby gem
#   json Ruby gem
#   beaneater Ruby gem
#
# Copyright 2014 99designs, Inc <devops@99designs.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'json'
require 'beaneater'

# Checks the queue levels
class BeanstalkdMetrics < Sensu::Plugin::Metric::CLI::Graphite

  option :server,
    description: 'beanstalkd server',
    short:       '-s SERVER',
    long:        '--server SERVER',
    default:     'localhost'

  option :port,
    description: 'beanstalkd server port',
    short:       '-p PORT',
    long:        '--port PORT',
    default:     '11300'

  option :scheme,
    :description => "Metric naming scheme, text to prepend to metric",
    :short => "-s SCHEME",
    :long => "--scheme SCHEME",
    :default => "#{Socket.gethostname}.beanstalkd"

  def get_beanstalkd_connection
    begin
      conn = Beaneater::Pool.new(["#{config[:server]}:#{config[:port]}"])
    rescue
      warning 'could not connect to beanstalkd'
    end
    conn
  end

  def run
    stats = get_beanstalkd_connection.stats

    stats.keys.sort.each do |key|
      next if key == 'version' # The version X.Y.Z is not a number
      output "#{config[:scheme]}.#{key}", stats.public_send(key)
    end

    ok
  end
end
