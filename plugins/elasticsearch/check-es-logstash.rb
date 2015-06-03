#!/usr/bin/env ruby
#
# Checks logstash index on ES
# ===
#
# DESCRIPTION:
#   This plugin checks the the logstash index on ES for logs from our host.
#
# OUTPUT:
#   plain-text
#
# PLATFORMS:
#   all
#
# DEPENDENCIES:
#   sensu-plugin Ruby gem
#   rest-client Ruby gem
#
# Copyright 2015 Marc Cluet <marc@ukoncherry.com>
# Based on code Copyright 2012 Sonian, Inc <chefs@sonian.net>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'rest-client'
require 'socket'
require 'json'

class LogstashES < Sensu::Plugin::Check::CLI

  ip = Socket.ip_address_list.detect{|intf| intf.ipv4_private?}

  option :hostname,
    :description => 'Our IP address',
    :short => '-n IP',
    :long => '--ip IP',
    :default => ip.ip_address

  option :host,
    :description => 'Elasticsearch host',
    :short => '-h HOST',
    :long => '--host HOST',
    :default => 'localhost'

  option :port,
    :description => 'Elasticsearch port',
    :short => '-p PORT',
    :long => '--port PORT',
    :proc => proc {|a| a.to_i },
    :default => 9200

  option :warning,
    :description => 'Warning number of lines',
    :short => '-w LINES',
    :long => '--warning LINES',
    :proc => proc {|a| a.to_i },
    :default => 100

  option :critical,
    :description => 'Critical number of lines',
    :short => '-c LINES',
    :long => '--critical LINES',
    :proc => proc {|a| a.to_i },
    :default => 10

  option :timeout,
    :description => 'Sets the connection timeout for REST client',
    :short => '-t SECS',
    :long => '--timeout SECS',
    :proc => proc {|a| a.to_i },
    :default => 30

  def run
    begin
      noindex = false
      t_logname = Time.now.strftime("logstash-%Y.%m.%d")
      y_logname = (Time.now-86400).strftime("logstash-%Y.%m.%d")
      q = '{ "query": { "filtered": { "query": { "term": { "host": "' + config[:hostname] + '" } }, "filter": { "bool": { "must": [ { "range": { "@timestamp": { "from": "now-1h", "to": "now" } } } ] } } } } }'
      r = RestClient::Request.new(
            :method => :post,
            :url => "http://#{config[:host]}:#{config[:port]}/#{y_logname},#{t_logname}/_count",
            :timeout => config[:timeout],
            :payload => q )
      json = r.execute
      result = JSON.parse(json) if json && json.length >= 2
    rescue Errno::ECONNREFUSED
      critical 'Connection refused'
    rescue RestClient::RequestTimeout
      critical 'Connection timed out'
    rescue Errno::ECONNRESET
      critical 'Connection reset by peer'
    rescue SocketError
      critical 'Cannot find ElasticSearch host'
    rescue => e
      critical "Index could not be found: #{e.response}"
    end
    if !result.nil? && !result.empty?
      mycount = result.fetch("count")
      # Sort out output
      if mycount.to_i > config[:warning].to_i
        ok "Found more than #{config[:warning]} lines"
      elsif mycount.to_i > config[:critical].to_i
        warning "Less than #{config[:warning]} lines found"
      else
        critical "Less than #{config[:critical]} lines found"
      end
    end
  end

end
