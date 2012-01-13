#!/usr/bin/env ruby
#
# RabbitMQ check alive plugin
# ===
#
# This plugin checks if RabbitMQ server is alive using the REST API 
#
# Copyright 2012 Abhijith G <abhi@runa.com> and Runa Inc.
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems'
require 'sensu-plugin/check/cli'
require 'json'
require 'rest_client'

class CheckRabbitMQ < Sensu::Plugin::Check::CLI

  option :host,
         :description => "RabbitMQ host",
         :short => '-w',
         :long => '--host HOST',
         :default => 'localhost'

  option :vhost,
         :description => "RabbitMQ vhost",
         :short => '-v',
         :long => '--vhost VHOST',
         :default => '%2F'

  option :username,
         :description => "RabbitMQ username",
         :short => '-u',
         :long => '--username USERNAME',
         :default => 'guest'

  option :password,
         :description => "RabbitMQ password",
         :short => '-p',
         :long => '--password PASSWORD',
         :default => 'guest'

  option :port,
         :description => "RabbitMQ API port",
         :short => '-P',
         :long => '--port PORT',
         :default => '55672'
  
  def run
    res = vhost_alive?
    
    if res.include? '{"status":"ok"}'
      ok "RabbitMQ server is alive"
    else
      critical "RabbitMQ server is dead"
    end
  end

  def vhost_alive?
    host     = config[:host]
    port     = config[:port]
    username = config[:username]
    password = config[:password]
    vhost    = config[:vhost]

    resource = RestClient::Resource.new "http://#{host}:#{port}/api/aliveness-test/#{vhost}"
    resource.get 
  end

end

