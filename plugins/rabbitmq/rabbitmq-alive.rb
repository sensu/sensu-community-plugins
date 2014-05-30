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

require 'rubygems' if RUBY_VERSION < '1.9.0'
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
    :default => '15672'

  option :ssl,
    :description => "Enable SSL for connection to RabbitMQ",
    :long => '--ssl',
    :boolean => true,
    :default => false

  def run
    res = vhost_alive?

    if res["status"] == "ok"
      ok res["message"]
    elsif res["status"] == "critical"
      critical res["message"]
    else
      unknown res["message"]
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
      resource = RestClient::Resource.new "http#{ssl ? 's' : ''}://#{host}:#{port}/api/aliveness-test/#{vhost}", username, password
      # Attempt to parse response (just to trigger parse exception)
      _response = JSON.parse(resource.get) == { "status" => "ok" }
      { "status" => "ok", "message" => "RabbitMQ server is alive" }
    rescue Errno::ECONNREFUSED => e
      { "status" => "critical", "message" => e.message }
    rescue Exception => e
      { "status" => "unknown", "message" => e.message }
    end
  end

end
