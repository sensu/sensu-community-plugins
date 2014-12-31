#!/usr/bin/env ruby
#
# Opsgenie handler which creates and closes alerts. Based on the pagerduty
# handler.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
require 'net/https'
require 'uri'
require 'json'

class Opsgenie < Sensu::Handler
  option :json_config,
         description: 'Configuration name',
         short: '-j JSONCONFIG',
         long: '--json JSONCONFIG',
         default: 'opsgenie'

  def handle
    @json_config = config[:json_config]
    description = @event['notification'] || [@event['client']['name'], @event['check']['name'], @event['check']['output'].chomp].join(' : ')

    begin
      timeout(3) do
        response = case @event['action']
                   when 'create'
                     create_alert(description)
                   when 'resolve'
                     close_alert
                   end
        if response['code'] == 200
          puts 'opsgenie -- ' + @event['action'].capitalize + 'd incident -- ' + event_id
        else
          puts 'opsgenie -- failed to ' + @event['action'] + ' incident -- ' + event_id
        end
      end
    rescue Timeout::Error
      puts 'opsgenie -- timed out while attempting to ' + @event['action'] + ' a incident -- ' + event_id
    end
  end

  def event_id
    @event['client']['name'] + '/' + @event['check']['name']
  end

  def event_status
    @event['check']['status']
  end

  def close_alert
    post_to_opsgenie(:close, alias: event_id)
  end

  def create_alert(description)
    tags = []
    tags << settings[@json_config]['tags'] if settings[@json_config]['tags']
    tags << 'OverwriteQuietHours' if event_status == 2 && settings[@json_config]['overwrite_quiet_hours'] == true
    tags << 'unknown' if event_status >= 3
    tags << 'critical' if event_status == 2
    tags << 'warning' if event_status == 1

    post_to_opsgenie(:create, alias: event_id, message: description, tags: tags.join(','))
  end

  def post_to_opsgenie(action = :create, params = {})
    params['customerKey'] = settings[@json_config]['customerKey']
    params['recipients']  = settings[@json_config]['recipients']

    # override source if specified, default is ip
    params['source'] = settings[@json_config]['source'] if settings[@json_config]['source']

    uripath = (action == :create) ? '' : 'close'
    uri = URI.parse("https://api.opsgenie.com/v1/json/alert/#{uripath}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    request = Net::HTTP::Post.new(uri.request_uri, 'Content-Type' => 'application/json')
    request.body = params.to_json
    response = http.request(request)
    JSON.parse(response.body)
  end
end
