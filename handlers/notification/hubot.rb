#!/usr/bin/env ruby
#
# Sensu Handler: Hubot
#
# This handler formats Sensu alerts and sends them to the Hubot http listener.
# This assumes your Hubot administrator has enabled the http-post-say plugin.
# https://github.com/github/hubot-scripts/blob/master/src/scripts/http-post-say.coffee
#
# Inspired from https://github.com/djbkd/sensu-hubot-handler.
#
# Configure via /etc/sensu/conf.d/hubot_handler.json
# {
#   "hubot": {
#     "server": "hubot.domain.tld",
#     "port": 8080,
#     "channel": "#irc-room"
#   }
# }
#
# Then add to your handler definitions
# {
#   "handlers": {
#     "default": {
#       "type": "set",
#       "handlers": ["hubot", "stdout"]
#     },
#     "hubot": {
#       "type": "pipe",
#       "command": "/etc/sensu/handlers/hubot.rb"
#     },
#     "stdout": {
#       "type": "pipe",
#       "command": "/bin/cat"
#     }
#   }
# }
#
require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'net/http'
require 'sensu-handler'
require 'timeout'

class Hubot < Sensu::Handler
  def event_name
    @event['client']['name'] + '/' + @event['check']['name']
  end

  def action_to_string
    @event['action'].eql?('resolve') ? 'RESOLVED' : 'ALERT'
  end

  def format_message
    message = @event['check']['notification'] || @event['check']['output']
    "#{action_to_string} - #{event_name}: #{message}"
  end

  def handle
    hubot_server  = settings['hubot']['server']
    hubot_port    = settings['hubot']['port']
    hubot_channel = settings['hubot']['channel']

    http = Net::HTTP.new(hubot_server, hubot_port)
    request = Net::HTTP::Post.new('/hubot/say')
    request.set_form_data('message' => format_message, 'room' => hubot_channel)

    begin
      timeout(10) do
        http.request(request)
      end
    rescue Timeout::Error
      puts "Hubot -- timed out while attempting message #{hubot_channel}"
    end
  end
end
