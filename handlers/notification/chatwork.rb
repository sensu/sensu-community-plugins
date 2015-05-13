#!/usr/bin/env ruby
#
## Sensu Handler: chatwork
##
## Copyright 2015, Tsubasa Hirota <tsubasa11@marble.ocn.ne.jp>
##
## Licensed under the Apache License, Version 2.0 (the "License");
## you may not use this file except in compliance with the License.
## You may obtain a copy of the License at
##
##     http://www.apache.org/licenses/LICENSE-2.0
##
## Unless required by applicable law or agreed to in writing, software
## distributed under the License is distributed on an "AS IS" BASIS,
## WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
## See the License for the specific language governing permissions and
## limitations under the License.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
require 'net/http'
require 'net/https'
require 'uri'
require 'timeout'

class ChatWkNotif < Sensu::Handler
  def server_url
    settings['chatwork']['serverurl'] || 'https://api.chatwork.com'
  end

  def api_token
    settings['chatwork']['apitoken']
  end

  def api_version
    settings['chatwork']['apiversion'] || 'v1'
  end

  def room_id
    settings['chatwork']['roomid']
  end

  def access_uri
    URI.parse("#{server_url}#{api_version}/rooms/#{room_id}/messages")
  end

  def access_header
    { 'X-ChatWorkToken' => "#{api_token}" }
  end

  def action_to_string
    @event['action'].eql?('resolve') ? 'RESOLVED' : 'ALERT'
  end

  def sensu_output
    @event['check']['notification'] || @event['check']['output']
  end

  def sensu_message
    "\s\s\s***#{action_to_string}***\s\s\s" + "\r\n" \
    'Time: ' + "#{Time.at(@event['check']['issued'])}" + "\r\n" \
    'Client: ' + @event['client']['name'] + "\r\n" \
    'Address: ' + @event['client']['address'] + "\r\n" \
    'Subscriptions: ' + @event['client']['subscriptions'].join(', ') + "\r\n" \
    'Check: ' + @event['check']['name'] + "\r\n" \
    'Output: ' + "#{sensu_output}" \
    "\s\s\s***by Sensu***\s\s\s"
  end

  def event_name
    @event['client']['name'] + '/' + @event['check']['name']
  end

  def handle
    http = Net::HTTP.new(access_uri.host, access_uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    body = 'body=' + URI.encode("#{sensu_message}")
    begin
      timeout(10) do
        res = http.post(access_uri, body, access_header)
        puts JSON.parse(res.body)
      end
    rescue Timeout::Error
      puts 'chatwork -- timed out while attempting to ' + @event['action'] + ' a incident -- ' + event_name
    rescue Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => e
      puts "chatwork -- HTTP Connection error #{e.message}"
    end
  end
end
