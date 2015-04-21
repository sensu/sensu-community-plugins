#!/usr/bin/env ruby
#  encoding: UTF-8
#
# RabbitMQ Queue Metrics
# ===
#
# DESCRIPTION:
# This plugin checks gathers the following per queue rabbitmq metrics:
#   - message count
#   - average egress rate
#   - "drain time" metric, which is the time a queue will take to reach 0 based on the egress rate
#   - consumer count
#
# PLATFORMS:
#   Linux, BSD, Solaris
#
# DEPENDENCIES:
#   RabbitMQ rabbitmq_management plugin
#   gem: sensu-plugin
#   gem: carrot-top
#
# LICENSE:
# Copyright 2011 Sonian, Inc <chefs@sonian.net>
# Copyright 2015 Tim Smith <tim@cozy.co> and Cozy Services Ltd.
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'sensu-plugin/metric/cli'
require 'socket'
require 'carrot-top'

# main plugin class
class RabbitMQMetrics < Sensu::Plugin::Metric::CLI::Graphite
  option :host,
         description: 'RabbitMQ management API host',
         long: '--host HOST',
         default: 'localhost'

  option :port,
         description: 'RabbitMQ management API port',
         long: '--port PORT',
         proc: proc(&:to_i),
         default: 15_672

  option :user,
         description: 'RabbitMQ management API user',
         long: '--user USER',
         default: 'guest'

  option :password,
         description: 'RabbitMQ management API password',
         long: '--password PASSWORD',
         default: 'guest'

  option :scheme,
         description: 'Metric naming scheme, text to prepend to $queue_name.$metric',
         long: '--scheme SCHEME',
         default: "#{Socket.gethostname}.rabbitmq"

  option :filter,
         description: 'Regular expression for filtering queues',
         long: '--filter REGEX'

  option :ssl,
         description: 'Enable SSL for connection to the API',
         long: '--ssl',
         boolean: true,
         default: false

  def acquire_rabbitmq_queues
    begin
      rabbitmq_info = CarrotTop.new(
        host: config[:host],
        port: config[:port],
        user: config[:user],
        password: config[:password],
        ssl: config[:ssl]
      )
    rescue
      warning 'could not get rabbitmq queue info'
    end
    rabbitmq_info.queues
  end

  def run
    timestamp = Time.now.to_i
    acquire_rabbitmq_queues.each do |queue|
      if config[:filter]
        next unless queue['name'].match(config[:filter])
      end

      # calculate and output time till the queue is drained in drain metrics
      drain_time = queue['messages'] / queue['backing_queue_status']['avg_egress_rate']
      drain_time = 0 if drain_time.nan? # 0 rate with 0 messages is 0 time to drain
      output([config[:scheme], queue['name'], 'drain_time'].join('.'), drain_time.to_i, timestamp)

      %w(messages consumers).each do |metric|
        output([config[:scheme], queue['name'], metric].join('.'), queue[metric], timestamp)
      end

      # fetch the average egress rate of the queue
      rate = sprintf('%.4f' % queue['backing_queue_status']['avg_egress_rate'])
      output([config[:scheme], queue['name'], 'avg_egress_rate'].join('.'), rate, timestamp)
    end
    ok
  end
end
