#!/usr/bin/env ruby
#  encoding: UTF-8
#   chatwork
#
# DESCRIPTION:
#   This handler sends Sensu event to ChatWork via HTTPS request. You can
#   change the handler settings using the chatwork.json configuration file,
#   located by default in /etc/sensu/conf.d directory.
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#
# USAGE:
#
# NOTES:
#
# LICENSE:
#   Tsubasa Hirota  tsubasa11@marble.ocn.ne.jp
#   Released under the same terms as Sensu (the MIT license); see     LICENSE
#   for details.
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
