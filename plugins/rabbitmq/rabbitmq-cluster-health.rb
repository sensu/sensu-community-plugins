#!/usr/bin/env ruby
#
# RabbitMQ check cluster nodes health plugin
# ===
#
# This plugin checks if RabbitMQ server's cluster nodes are in a running state.
# It also accepts and optional list of nodes and verifies that those nodes are
# present in the cluster.
# The plugin is based on the RabbitMQ alive plugin by Abhijith G.
#
#  Todo:
#    - Add ability to specify http vs. https
#
# Copyright 2012 Abhijith G <abhi@runa.com> and Runa Inc.
# Copyright 2014 Tim Smith <tim@cozy.co> and Cozy Services Ltd.
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'json'
require 'rest_client'

class CheckRabbitMQCluster < Sensu::Plugin::Check::CLI
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
         description: 'RabbitMQ API port',
         short: '-P',
         long: '--port PORT',
         default: '15672'

  option :nodes,
         description: 'Optional comma separated list of expected nodes in the cluster',
         short: '-n',
         long: '--nodes NODE1,NODE2',
         default: ''

  def run
    res = cluster_healthy?

    if res['status'] == 'ok'
      ok res['message']
    elsif res['status'] == 'critical'
      critical res['message']
    else
      unknown res['message']
    end
  end

  def missing_nodes?(nodes, servers_status)
    missing = []
    if nodes.empty?
      missing
    else
      nodes.reject { |x| servers_status.keys.include?(x) }
    end
  end

  def failed_nodes?(servers_status)
    failed_nodes = []
    servers_status.each { |sv, stat| failed_nodes << sv unless stat == true }
    failed_nodes
  end

  def cluster_healthy?
    host     = config[:host]
    port     = config[:port]
    username = config[:username]
    password = config[:password]
    nodes   =  config[:nodes].split(',')

    begin
      resource = RestClient::Resource.new "http://#{host}:#{port}/api/nodes", username, password
      # create a hash of the server names and their running state
      servers_status = Hash[JSON.parse(resource.get).map { |server| [server['name'], server['running']] }]

      # true or false for health of the nodes
      missing_nodes = missing_nodes?(nodes, servers_status)

      # array of nodes that are not running
      failed_nodes = failed_nodes?(servers_status)

      # build status and message
      status = failed_nodes.empty? && missing_nodes.empty? ? 'ok' : 'critical'
      if failed_nodes.empty?
        message = "#{servers_status.keys.count} healthy cluster nodes"
      else
        message = "#{failed_nodes.count} failed cluster node: #{failed_nodes.sort.join(',')}"
      end
      message.prepend("#{missing_nodes.count } node(s) not found: #{missing_nodes.join(',')}. ") unless missing_nodes.empty?
      { 'status' => status, 'message' => message }
    rescue Errno::ECONNREFUSED => e
      { 'status' => 'critical', 'message' => e.message }
    rescue => e
      { 'status' => 'unknown', 'message' => e.message }
    end
  end
end
