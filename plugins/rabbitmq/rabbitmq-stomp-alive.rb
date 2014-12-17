#!/usr/bin/env ruby
#
# RabbitMQ check alive plugin
# ===
#
# This plugin checks if RabbitMQ server is alive and responding to STOMP
# requests.
#
# Copyright 2014 Adam Ashley
# Based on rabbitmq-amqp-alive by Milos Gajdos
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'stomp'

class CheckRabbitStomp < Sensu::Plugin::Check::CLI
  option :host,
         description: 'RabbitMQ host',
         short: '-w',
         long: '--host HOST',
         default: 'localhost'

  option :username,
         description: 'RabbitMQ username',
         short: '-u',
         long: '--username USERNAME',
         default: 'guest'

  option :password,
         description: 'RabbitMQ password',
         short: '-p',
         long: '--password PASSWORD',
         default: 'guest'

  option :port,
         description: 'RabbitMQ STOMP port',
         short: '-P',
         long: '--port PORT',
         default: '61613'

  option :ssl,
         description: 'Enable SSL for connection to RabbitMQ',
         long: '--ssl',
         boolean: true,
         default: false

  option :queue,
         description: 'Queue to post a message to and receive from',
         short: '-q',
         long: '--queue QUEUE',
         default: 'aliveness-test'

  def run
    res = vhost_alive?

    if res['status'] == 'ok'
      ok res['message']
    elsif res['status'] == 'critical'
      critical res['message']
    else
      unknown res['message']
    end
  end

  def vhost_alive?
    hash = {
      hosts: [
        {
          login: config[:username],
          passcode: config[:password],
          host: config[:host],
          port: config[:port],
          ssl: config[:ssl]
        }
      ],
      reliable: false, # disable failover
      connect_timeout: 10
    }

    begin
      conn = Stomp::Client.new(hash)
      conn.publish("/queue/#{config[:queue]}", 'STOMP Alive Test')
      conn.subscribe("/queue/#{config[:queue]}") do |_msg|
      end
      { 'status' => 'ok', 'message' => 'RabbitMQ server is alive' }
     rescue Errno::ECONNREFUSED
       { 'status' => 'critical', 'message' => 'TCP connection refused' }
     rescue Stomp::Error::BrokerException => e
       { 'status' => 'critical', 'message' => "Error from broker. Check auth details? #{e.message}" }
    rescue => e
      { 'status' => 'unknown', 'message' => "#{e.class}: #{e.message}" }
    end
  end
end
