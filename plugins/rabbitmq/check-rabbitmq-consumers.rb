#!/usr/bin/env ruby
#
# Check RabbitMQ consumers
# ========================
#
# Copyright 2014 Daniel Kerwin <d.kerwin@gini.net>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'carrot-top'

class CheckRabbitMQMessages < Sensu::Plugin::Check::CLI

  option :host,
    :description => "RabbitMQ management API host",
    :long => "--host HOST",
    :default => "localhost"

  option :port,
    :description => "RabbitMQ management API port",
    :long => "--port PORT",
    :proc => proc { |p| p.to_i },
    :default => 15672

  option :ssl,
    :description => "Enable SSL for connection to the API",
    :long => "--ssl",
    :boolean => true,
    :default => false

  option :user,
    :description => "RabbitMQ management API user",
    :long => "--user USER",
    :default => "guest"

  option :password,
    :description => "RabbitMQ management API password",
    :long => "--password PASSWORD",
    :default => "guest"

  option :queue,
    :description => "RabbitMQ queue to monitor",
    :long => "--queue queue_name",
    :required => true

  option :warn,
    :short => '-w NUM_CONSUMERS',
    :long => '--warn NUM_CONSUMERS',
    :proc => proc { |w| w.to_i },
    :description => 'WARNING consumer count threshold',
    :default => 5

  option :critical,
    :short => '-c NUM_CONSUMERS',
    :long => '--critical NUM_CONSUMERS',
    :description => 'CRITICAL consumer count threshold',
    :proc => proc { |c| c.to_i },
    :default => 2

  def rabbit
    begin
      connection = CarrotTop.new(
        host: config[:host],
        port: config[:port],
        user: config[:user],
        password: config[:password],
        ssl: config[:ssl],
      )
    rescue
      warning "could not connect to rabbitmq"
    end
    connection
  end

  def run
    rabbit.queues.each do |queue|
      if queue['name'] == config[:queue]
        consumers = queue['consumers']
        message "#{consumers} connected"
        critical if consumers < config[:critical]
        warning if consumers < config[:warn]
        ok
      end
    end

    warning "No Queue: #{config[:queue]}"
    ok
  end

end
