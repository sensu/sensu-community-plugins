#!/usr/bin/env ruby
#
# Check RabbitMQ consumers
# ========================
#
# Copyright 2014 Daniel Kerwin <d.kerwin@gini.net>
# Copyright 2014 Tim Smith <tim@cozy.co>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'carrot-top'

class CheckRabbitMQConsumers < Sensu::Plugin::Check::CLI
  option :host,
         description: 'RabbitMQ management API host',
         long: '--host HOST',
         default: 'localhost'

  option :port,
         description: 'RabbitMQ management API port',
         long: '--port PORT',
         proc: proc(&:to_i),
         default: 15_672

  option :ssl,
         description: 'Enable SSL for connection to the API',
         long: '--ssl',
         boolean: true,
         default: false

  option :user,
         description: 'RabbitMQ management API user',
         long: '--user USER',
         default: 'guest'

  option :password,
         description: 'RabbitMQ management API password',
         long: '--password PASSWORD',
         default: 'guest'

  option :queue,
         description: 'RabbitMQ queue to monitor. To check 2+ queues use a comma separated list',
         long: '--queue queue_name',
         required: true,
         proc: proc { |q| q.split(',') }

  option :warn,
         short: '-w NUM_CONSUMERS',
         long: '--warn NUM_CONSUMERS',
         proc: proc(&:to_i),
         description: 'WARNING consumer count threshold',
         default: 5

  option :critical,
         short: '-c NUM_CONSUMERS',
         long: '--critical NUM_CONSUMERS',
         description: 'CRITICAL consumer count threshold',
         proc: proc(&:to_i),
         default: 2

  def rabbit
    begin
      connection = CarrotTop.new(
        host: config[:host],
        port: config[:port],
        user: config[:user],
        password: config[:password],
        ssl: config[:ssl]
      )
    rescue
      warning 'could not connect to rabbitmq'
    end
    connection
  end

  def return_condition(missing, critical, warning)
    if critical.count > 0 || missing.count > 0
      message = ''
      message << "Queues in critical state: #{critical.join(', ')}. " if critical.count > 0
      message << "Queues missing: #{missing.join(', ')}" if missing.count > 0
      critical(message)
    elsif warning.count > 0
      warning("Queues in warning state: #{warning.join(', ')}")
    else
      ok
    end
  end

  def run
    # create arrays to hold failures
    missing = config[:queue]
    critical = []
    warn = []

    rabbit.queues.each do |queue|
      next unless config[:queue].include?(queue['name'])
      missing.delete(queue['name'])
      consumers = queue['consumers']
      critical.push(queue['name']) if consumers < config[:critical]
      warn.push(queue['name']) if consumers < config[:warn]
    end

    return_condition(missing, critical, warn)
  end
end
