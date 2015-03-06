#!/usr/bin/env ruby

#
# RabbitMQ Overview Metrics
# ===
#
# Dependencies
# -----------
# - RabbitMQ `rabbitmq_management` plugin
# - Ruby gem `carrot-top`
#
# Overview stats
# ---------------
# RabbitMQ 'overview' stats are similar to what is shown on the main page
# of the rabbitmq_management web UI. Example:
#
#   $ rabbitmq-queue-metrics.rb
#    host.rabbitmq.queue_totals.messages.count 0 1344186404
#    host.rabbitmq.queue_totals.messages.rate  0.0 1344186404
#    host.rabbitmq.queue_totals.messages_unacknowledged.count  0 1344186404
#    host.rabbitmq.queue_totals.messages_unacknowledged.rate 0.0 1344186404
#    host.rabbitmq.queue_totals.messages_ready.count 0 1344186404
#    host.rabbitmq.queue_totals.messages_ready.rate  0.0 1344186404
#    host.rabbitmq.message_stats.publish.count 4605755 1344186404
#    host.rabbitmq.message_stats.publish.rate  17.4130186829638  1344186404
#    host.rabbitmq.message_stats.deliver_no_ack.count  6661111 1344186404
#    host.rabbitmq.message_stats.deliver_no_ack.rate 24.6867565643405  1344186404
#    host.rabbitmq.message_stats.deliver_get.count 6661111 1344186404
#    host.rabbitmq.message_stats.deliver_get.rate  24.6867565643405  1344186404#
#
# Copyright 2012 Joe Miller - https://github.com/joemiller
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'socket'
require 'carrot-top'

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

  option :ssl,
         description: 'Enable SSL for connection to the API',
         long: '--ssl',
         boolean: true,
         default: false

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
      warning 'could not get rabbitmq info'
    end
    rabbitmq_info
  end

  def run
    timestamp = Time.now.to_i

    rabbitmq = acquire_rabbitmq_info
    overview = rabbitmq.overview

    # overview['queue_totals']['messages']
    if overview.key?('queue_totals') && !overview['queue_totals'].empty?
      output "#{config[:scheme]}.queue_totals.messages.count", overview['queue_totals']['messages'], timestamp
      output "#{config[:scheme]}.queue_totals.messages.rate", overview['queue_totals']['messages_details']['rate'], timestamp

      # overview['queue_totals']['messages_unacknowledged']
      output "#{config[:scheme]}.queue_totals.messages_unacknowledged.count", overview['queue_totals']['messages_unacknowledged'], timestamp
      output "#{config[:scheme]}.queue_totals.messages_unacknowledged.rate", overview['queue_totals']['messages_unacknowledged_details']['rate'], timestamp

      # overview['queue_totals']['messages_ready']
      output "#{config[:scheme]}.queue_totals.messages_ready.count", overview['queue_totals']['messages_ready'], timestamp
      output "#{config[:scheme]}.queue_totals.messages_ready.rate", overview['queue_totals']['messages_ready_details']['rate'], timestamp
    end

    if overview.key?('message_stats') && !overview['message_stats'].empty?
      # overview['message_stats']['publish']
      if overview['message_stats'].include?('publish')
        output "#{config[:scheme]}.message_stats.publish.count", overview['message_stats']['publish'], timestamp
      end
      if overview['message_stats'].include?('publish_details') &&
         overview['message_stats']['publish_details'].include?('rate')
        output "#{config[:scheme]}.message_stats.publish.rate", overview['message_stats']['publish_details']['rate'], timestamp
      end

      # overview['message_stats']['deliver_no_ack']
      if overview['message_stats'].include?('deliver_no_ack')
        output "#{config[:scheme]}.message_stats.deliver_no_ack.count", overview['message_stats']['deliver_no_ack'], timestamp
      end
      if overview['message_stats'].include?('deliver_no_ack_details') &&
         overview['message_stats']['deliver_no_ack_details'].include?('rate')
        output "#{config[:scheme]}.message_stats.deliver_no_ack.rate", overview['message_stats']['deliver_no_ack_details']['rate'], timestamp
      end

      # overview['message_stats']['deliver_get']
      if overview['message_stats'].include?('deliver_get')
        output "#{config[:scheme]}.message_stats.deliver_get.count", overview['message_stats']['deliver_get'], timestamp
      end
      if overview['message_stats'].include?('deliver_get_details') &&
         overview['message_stats']['deliver_get_details'].include?('rate')
        output "#{config[:scheme]}.message_stats.deliver_get.rate", overview['message_stats']['deliver_get_details']['rate'], timestamp
      end
    end
    ok
  end
end
