#!/usr/bin/env ruby
#  encoding: UTF-8
#
# Check RabbitMQ Messages
# ===
#
# DESCRIPTION:
# This plugin checks the total number of messages queued on the RabbitMQ server
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
# Copyright 2012 Evan Hazlett <ejhazlett@gmail.com>
# Copyright 2015 Tim Smith <tim@cozy.co> and Cozy Services Ltd.
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'sensu-plugin/check/cli'
require 'socket'
require 'carrot-top'

# main plugin class
class CheckRabbitMQMessages < Sensu::Plugin::Check::CLI
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

  option :ssl,
         description: 'Enable SSL for connection to the API',
         long: '--ssl',
         boolean: true,
         default: false

  option :warn,
         short: '-w NUM_MESSAGES',
         long: '--warn NUM_MESSAGES',
         description: 'WARNING message count threshold',
         default: 250

  option :critical,
         short: '-c NUM_MESSAGES',
         long: '--critical NUM_MESSAGES',
         description: 'CRITICAL message count threshold',
         default: 500

  option :queuelevel,
         short: '-q',
         long: '--queuelevel',
         description: 'Monitors that no individual queue is above the thresholds specified'

  option :excluded,
         short: '-e queue_name',
         long: '--excludedqueues queue_name',
         description: 'Comma separated list of queues to exclude when using queue level monitoring',
         proc: proc { |q| q.split(',') },
         default: []

  def generate_message(status_hash)
    message =  []
    status_hash.each_pair do |k, v|
      message << "#{k}: #{v}"
    end
    message.join(', ')
  end

  def acquire_rabbitmq_info
    begin
      rabbitmq_info = CarrotTop.new(
        host: config[:host],
        port: config[:port],
        user: config[:user],
        password: config[:password],
        ssl: config[:ssl]
      )
    rescue
      warning 'Could not connect to rabbitmq'
    end
    rabbitmq_info
  end

  def run
    rabbitmq = acquire_rabbitmq_info

    # monitor counts in each queue or monitor the total number of messages in the system
    if config[:queuelevel]
      warn_queues = {}
      crit_queues = {}
      rabbitmq.queues.each do |queue|
        next if config[:excluded].include?(queue['name'])
        (crit_queues["#{queue['name']}"] = queue['messages']; next) if queue['messages'] >= config[:critical].to_i # rubocop: disable Style/Semicolon
        (warn_queues["#{queue['name']}"] = queue['messages']; next) if queue['messages'] >= config[:warn].to_i # rubocop: disable Style/Semicolon
      end
      message crit_queues.empty? ? generate_message(warn_queues) : generate_message(crit_queues)
      critical unless crit_queues.empty?
      warning unless warn_queues.empty?
    else
      total = rabbitmq.overview['queue_totals']['messages']
      message "#{total}"
      critical if total > config[:critical].to_i
      warning if total > config[:warn].to_i
    end
    ok
  end
end
