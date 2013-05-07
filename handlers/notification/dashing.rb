#!/usr/bin/env ruby
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
require 'net/http'

class DashingNotif < Sensu::Handler

  def widget
    @event['client']['name'] + '-' + @event['check']['name']
  end

  def handle
    token = settings['dashing']['auth_token']
    data = @event['check']['output']
    payload = {"auth_token" => "#{token}", "event" => "#{data}"}.to_json

    uri = URI.parse(settings['dashing']['host'])
    http = Net::HTTP.new(uri.host, uri.port)
    http.post("/widgets/#{widget}", payload)
  end

end
