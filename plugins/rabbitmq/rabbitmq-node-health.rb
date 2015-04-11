#!/usr/bin/env ruby
#
# RabbitMQ check node health plugin
# ===
#
# This plugin checks if RabbitMQ server node is in a running state.
#
# The plugin is based on the RabbitMQ cluster node health plugin by Tim Smith
#
#
# Copyright 2012 Abhijith G <abhi@runa.com> and Runa Inc.
# Copyright 2014 Tim Smith <tim@cozy.co> and Cozy Services Ltd.
# Copyright 2015 Edward McLain <ed@edmclain.com> and Daxko, LLC.
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'json'
require 'rest-client'

class CheckRabbitMQNode < Sensu::Plugin::Check::CLI
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

  option :memwarn,
         description: 'Warning % of mem usage vs high watermark',
         short: '-m',
         long: '--mwarn PERCENT',
         proc: proc(&:to_f),
         default: 80

  option :memcrit,
         description: 'Critical % of mem usage vs high watermark',
         short: '-c',
         long: '--mcrit PERCENT',
         proc: proc(&:to_f),
         default: 90

  option :fdwarn,
         description: 'Warning % of file descriptor usage vs high watermark',
         short: '-m',
         long: '--mwarn PERCENT',
         proc: proc(&:to_f),
         default: 80

  option :fdcrit,
         description: 'Critical % of file descriptor usage vs high watermark',
         short: '-c',
         long: '--mcrit PERCENT',
         proc: proc(&:to_f),
         default: 90

  option :socketwarn,
         description: 'Warning % of socket usage vs high watermark',
         short: '-m',
         long: '--mwarn PERCENT',
         proc: proc(&:to_f),
         default: 80

  option :socketcrit,
         description: 'Critical % of socket usage vs high watermark',
         short: '-c',
         long: '--mcrit PERCENT',
         proc: proc(&:to_f),
         default: 90

  option :watchalarms,
         description: 'Sound critical if one or more alarms are triggered',
         short: '-a BOOLEAN',
         long: '--alarms BOOLEAN',
         default: 'true'

  def run
    res = node_healthy?

    if res['status'] == 'ok'
      ok res['message']
    elsif res['status'] == 'warning'
      warning res['message']
    elsif res['status'] == 'critical'
      critical res['message']
    else
      unknown res['message']
    end
  end

  def node_healthy?
    host     = config[:host]
    port     = config[:port]
    username = config[:username]
    password = config[:password]

    begin
      resource = RestClient::Resource.new "http://#{host}:#{port}/api/nodes", username, password
      # Parse our json data
      nodeinfo = JSON.parse(resource.get)[0]

      # Determine % memory consumed
      pmem = sprintf('%.2f', nodeinfo['mem_used'].fdiv(nodeinfo['mem_limit']) * 100)
      # Determine % sockets consumed
      psocket = sprintf('%.2f', nodeinfo['sockets_used'].fdiv(nodeinfo['sockets_total']) * 100)
      # Determine % file descriptors consumed
      pfd = sprintf('%.2f', nodeinfo['fd_used'].fdiv(nodeinfo['fd_total']) * 100)

      # build status and message
      status = 'ok'
      message = 'Server is healthy'

      # criticals
      if pmem.to_f >= config[:memcrit]
        message = "Memory usage is critical: #{pmem}%"
        status = 'critical'
      elsif psocket.to_f >= config[:socketcrit]
        message = "Socket usage is critical: #{psocket}%"
        status = 'critical'
      elsif pfd.to_f >= config[:fdcrit]
        message = "Socket usage is critical: #{pfd}%"
        status = 'critical'
      # warnings
      elsif pmem.to_f >= config[:memwarn]
        message = "Memory usage is at warning: #{pmem}%"
        status = 'warning'
      elsif psocket.to_f >= config[:socketwarn]
        message = "Socket usage is at warning: #{psocket}%"
        status = 'warning'
      elsif pfd.to_f >= config[:fdwarn]
        message = "Socket usage is at warning: #{pfd}%"
        status = 'warning'
      end

      # If we are set to watch alarms then watch those and set status and messages accordingly
      if config[:watchalarms] == 'true'
        if nodeinfo['mem_alarm'] == true
          status = 'critical'
          message += ' Memory Alarm ON'
        end

        if nodeinfo['disk_free_alarm'] == true
          status = 'critical'
          message += ' Disk Alarm ON'
        end
      end

      { 'status' => status, 'message' => message }
    rescue Errno::ECONNREFUSED => e
      { 'status' => 'critical', 'message' => e.message }
    rescue => e
      { 'status' => 'unknown', 'message' => e.message }
    end
  end
end
