#!/usr/bin/env ruby

# Copyright 2014 Dan Shultz and contributors.
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.
#
# In order to use this plugin, you must first configure an incoming webhook
# integration in slack. You can create the required webhook by visiting
# https://{your team}.slack.com/services/new/incoming-webhook
#
# After you configure your webhook, you'll need the webhook URL from the integration.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
require 'json'

class Slack < Sensu::Handler
  def slack_webhook_url
    get_setting('webhook_url')
  end

  def slack_message_prefix
    get_setting('message_prefix')
  end

  def slack_bot_name
    get_setting('bot_name')
  end

  def slack_surround
    get_setting('surround')
  end

  def incident_key
    @event['client']['name'] + '/' + @event['check']['name']
  end

  def get_setting(name)
    settings['slack'][name]
  end

  def handle
    description = @event['notification'] || build_description
    post_data("#{incident_key}: #{description}")
  end

  def build_description
    [
      @event['check']['output'],
      @event['client']['address'],
      @event['client']['subscriptions'].join(',')
    ].join(' : ')
  end

  def post_data(notice)
    uri = URI(slack_webhook_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    req = Net::HTTP::Post.new("#{uri.path}?#{uri.query}")
    text = slack_surround ? slack_surround + notice + slack_surround : notice
    req.body = "payload=#{payload(text).to_json}"

    response = http.request(req)
    verify_response(response)
  end

  def verify_response(response)
    case response
    when Net::HTTPSuccess
      true
    else
      fail response.error!
    end
  end

  def payload(notice)
    {
      icon_url: 'http://sensuapp.org/img/sensu_logo_large-c92d73db.png',
      attachments: [{
        text: [slack_message_prefix, notice].compact.join(' '),
        color: color
      }]
    }.tap do |payload|
      payload[:username] = slack_bot_name if slack_bot_name
    end
  end

  def color
    color = {
      0 => '#36a64f',
      1 => '#FFCC00',
      2 => '#FF0000',
      3 => '#6600CC'
    }
    color.fetch(check_status.to_i)
  end

  def check_status
    @event['check']['status']
  end
end
