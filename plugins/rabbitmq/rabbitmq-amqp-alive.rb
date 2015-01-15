#!/usr/bin/env ruby
#
# RabbitMQ check alive plugin
# ===
#
# This plugin checks if RabbitMQ server is alive using the REST API
#
# Copyright 2013 Milos Gajdos
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'bunny'

class CheckRabbitAMQP < Sensu::Plugin::Check::CLI
  option :host,
         description: 'RabbitMQ host',
         short: '-w',
         long: '--host HOST',
         default: 'localhost'

  option :vhost,
         description: 'RabbitMQ vhost',
         short: '-v',
         long: '--vhost VHOST',
         default: '%2F'

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
         description: 'RabbitMQ AMQP port',
         short: '-P',
         long: '--port PORT',
         default: '5672'

  option :ssl,
         description: 'Enable SSL for connection to RabbitMQ',
         long: '--ssl',
         boolean: true,
         default: false

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
    host     = config[:host]
    port     = config[:port]
    username = config[:username]
    password = config[:password]
    vhost    = config[:vhost]
    ssl      = config[:ssl]

    begin
      conn = Bunny.new("amqp#{ssl ? 's' : ''}://#{username}:#{password}@#{host}:#{port}/#{vhost}")
      conn.start
      { 'status' => 'ok', 'message' => 'RabbitMQ server is alive' }
    rescue Bunny::PossibleAuthenticationFailureError
      { 'status' => 'critical', 'message' => 'Possible authentication failure' }
    rescue Bunny::TCPConnectionFailed
      { 'status' => 'critical', 'message' => 'TCP connection refused' }
    rescue => e
      { 'status' => 'unknown', 'message' => e.message }
    end
  end
end
