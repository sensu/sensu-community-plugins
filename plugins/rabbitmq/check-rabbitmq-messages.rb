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
    :description => "RabbitMQ management API host",
    :long => "--host HOST",
    :default => "localhost"

  option :port,
    :description => "RabbitMQ management API port",
    :long => "--port PORT",
    :proc => proc {|p| p.to_i},
    :default => 55672

  option :user,
    :description => "RabbitMQ management API user",
    :long => "--user USER",
    :default => "guest"

  option :password,
    :description => "RabbitMQ management API password",
    :long => "--password PASSWORD",
    :default => "guest"

  option :ignore,
    :description => 'A comma-separated list of Queues to ignore',
    :short => '-i QUEUE_NAME[,QUEUE_NAME]',
    :long => '--ignore QUEUE_NAME[,QUEUE_NAME]'

  option :warn,
    :short => '-w NUM_MESSAGES',
    :long => '--warn NUM_MESSAGES',
    :description => 'WARNING message count threshold',
    :default => 250

  option :critical,
    :short => '-c NUM_MESSAGES',
    :long => '--critical NUM_MESSAGES',
    :description => 'CRITICAL message count threshold',
    :default => 500

  def rabbitmq
    @rabbitmq ||= begin
      CarrotTop.new(
        :host => config[:host],
        :port => config[:port],
        :user => config[:user],
        :password => config[:password]
      )
    rescue
      message "Could not connect to RabbitMQ"
      exit 1
    end
  end

  def run
    queues = {}
    if config[:ignore]
      items = config[:ignore].split(',')
      rabbitmq.queues.each do |q|
        next if items.include?(q['name'])
        queues[q['name']] = q['messages'] || 0
      end
    else
      rabbitmq.queues.each { |q| queues[q['name']] = q['messages'] || 0 }
    end

    crit = false
    warn = false
    queues.each do |name,count|
      if count > config[:critical].to_i
        output "[CRITICAL] #{name}: #{count}"
        crit = true
      elsif count > config[:warn].to_i
        output "[WARNING] #{name}: #{count}"
        warn = true
      end
    end

    critical if crit
    warning if warn
    ok
  end

end
