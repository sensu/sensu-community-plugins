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
# After you configure your webhook, you'll need to token from the integration.
# The default channel and bot name entered can be overridden by this handlers
# configuration.
#
# Minimum configuration required is the 'token' and 'team_name'

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
require 'json'

class Slack < Sensu::Handler

  def slack_token
    get_setting('token')
  end

  def slack_channel
    get_setting('channel')
  end

  def slack_message_prefix
    get_setting('message_prefix')
  end

  def slack_team_name
    get_setting('team_name')
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
    settings["slack"][name]
  end

  def handle
    description = @event['notification'] || build_description
    post_data("#{incident_key}: #{description}")
  end

  def build_description
    [
      @event['client']['name'],
      @event['check']['name'],
      @event['check']['output'],
      @event['client']['address'],
      @event['client']['subscriptions'].join(',')
    ].join(' : ')
  end

  def post_data(notice)
    uri = slack_uri(slack_token)
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
        raise response.error!
    end
  end

  def payload(notice)
    {
      :link_names => 1,
      :text => [slack_message_prefix, notice].compact.join(' '),
      :icon_emoji => icon_emoji
    }.tap do |payload|
      payload[:channel] = slack_channel if slack_channel
      payload[:username] = slack_bot_name if slack_bot_name
    end
  end

  def icon_emoji
    default = ":feelsgood:"
    emoji = {
      0 => ':godmode:',
      1 => ':hurtrealbad:',
      2 => ':feelsgood:'
    }
    emoji.fetch(check_status.to_i, default)
  end

  def check_status
    @event['check']['status']
  end

  def slack_uri(token)
    url = "https://#{slack_team_name}.slack.com/services/hooks/incoming-webhook?token=#{token}"
    URI(url)
  end

end
