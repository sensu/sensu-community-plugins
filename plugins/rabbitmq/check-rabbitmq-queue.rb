#!/usr/bin/env ruby
#
# Check RabbitMQ messages
# ===
#
# Copyright 2012 Evan Hazlett <ejhazlett@gmail.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'socket'
require 'carrot-top'

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
         description: 'RabbitMQ queue to monitor',
         long: '--queue queue_names',
         required: true,
         proc: proc { |a| a.split(',') }

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
    @crit = []
    @warn = []
    rabbitmq = acquire_rabbitmq_info
    queues = rabbitmq.queues
    config[:queue].each do |q|
      unless queues.map  { |hash| hash['name'] }.include? q
        @warn << "Queue #{ q } not available"
        next
      end
      queues.each do |queue|
        if queue['name'] == q
          total = queue['messages']
          if total.nil?
            total = 0
          end
          message "#{total}"
          @crit <<  "#{ q }:#{ total }" if total > config[:critical].to_i
          @warn << "#{ q }:#{ total }" if total > config[:warn].to_i
        end
      end
    end
    if @crit.empty? && @warn.empty?
      ok
    elsif !(@crit.empty?)
      critical "critical: #{ @crit } warning: #{ @warn }"
    elsif !(@warn.empty?)
      warning "critical: #{ @crit } warning: #{ @warn }"
    end
  end
end
