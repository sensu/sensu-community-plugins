#!/usr/bin/env ruby
#
# Get the length of a list and push it to graphite
#
#
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'redis'

class RedisListLengthMetric < Sensu::Plugin::Metric::CLI::Graphite
  option :host,
         short: '-h HOST',
         long: '--host HOST',
         description: 'Redis Host to connect to',
         default: '127.0.0.1'

  option :port,
         short: '-p PORT',
         long: '--port PORT',
         description: 'Redis Port to connect to',
         proc: proc(&:to_i),
         default: 6379

  option :password,
         short: '-P PASSWORD',
         long: '--password PASSWORD',
         description: 'Redis Password to connect with'

  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         default: "#{Socket.gethostname}.redis"

  option :key,
         short: '-k KEY',
         long: '--key KEY',
         description: 'Redis list KEY to check',
         required: true

  def run
    options = { host: config[:host], port: config[:port] }
    options[:password] = config[:password] if config[:password]
    redis = Redis.new(options)

    output "#{config[:scheme]}.#{config[:key]}.items", redis.llen(config[:key])
    ok
  end
end
