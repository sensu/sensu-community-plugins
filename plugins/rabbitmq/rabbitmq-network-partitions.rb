#!/usr/bin/env ruby
#
# RabbitMQ Network Partitions Check
# ===
#
# This plugin checks if a RabbitMQ network partition has occured.
# https://www.rabbitmq.com/partitions.html
#
# DEPENDENCIES:
# gem: sensu-plugin
# gem: carrot-top
#
# Copyright 2015 Ed Robinson <ed@reevoo.com> and Reevoo LTD.
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'carrot-top'

class CheckRabbitMQPartitions < Sensu::Plugin::Check::CLI
  option :host,
         description: 'RabbitMQ management API host',
         short: '-w',
         long: '--host HOST',
         default: 'localhost'

  option :port,
         description: 'RabbitMQ management API port',
         long: '--port PORT',
         proc: proc(&:to_i),
         default: 15_672

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

  option :ssl,
         description: 'Enable SSL for connection to the API',
         long: '--ssl',
         boolean: true,
         default: false

  def run
    critical 'network partition detected' if partition?
    ok 'no network partition detected'
  rescue Errno::ECONNREFUSED => e
    critical e.message
  rescue => e
    unknown e.message
  end

  def partition?
    rabbitmq_management.nodes.map { |node| node['partitions'] }.any?(&:any?)
  end

  def rabbitmq_management
    CarrotTop.new(
      host: config[:host],
      port: config[:port],
      user: config[:username],
      password: config[:password],
      ssl: config[:ssl]
    )
  end
end
