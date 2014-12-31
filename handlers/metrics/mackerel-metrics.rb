#!/usr/bin/env ruby
#
# Sensu mackerel Handler
# ===
#
# -----------------------------
#
# mackerel
#
#  All your server are belong to us.
#
#  https://mackerel.io
# -----------------------------
#
# Mackerel handler has following options:
#  - api_key: GET https://mackerel.io/
#  -  hostid: rpm install (/var/lib/mackerel-agent/id)
#
# Copyright 2014 kenjiskywalker <kenji@kenjiskywalker.org>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
require 'net/http'
require 'json'
require 'openssl'
require 'timeout'

class Mackerel < Sensu::Handler
  def handle
    origin  = settings['mackerel']['origin'] || 'https://mackerel.io'
    api_key = settings['mackerel']['api_key']
    hostid  = settings['mackerel']['hostid']

    @event['check']['output'].split("\n").each do |line|
      v = line.split("\t")

      metrics = [{
        hostId: hostid,
        name: format('%{custom}.%{name}', custom: 'custom', name: v[0]),
        value: v[1].to_i,
        time: v[2].to_i
      }]

      begin
        timeout(30) do
          uri = URI("#{origin}/api/v0/tsdb")
          https = Net::HTTP.new(uri.host, uri.port)
          https.use_ssl = true
          https.verify_mode = OpenSSL::SSL::VERIFY_NONE
          request = Net::HTTP::Post.new(uri.path)
          request['Content-Type'] = 'application/json; charset=utf-8'
          request['X-Api-Key'] = api_key

          request.body = JSON.dump(metrics)
          response = https.request(request)

          if response.code == '200'
            puts "mackerel -- success #{response.body}"
          else
            puts "mackerel -- fail #{response.body}"
          end
        end
      rescue Timeout::Error
        puts "mackerel -- timeout #{response.body}"
      end
    end
  end
end
