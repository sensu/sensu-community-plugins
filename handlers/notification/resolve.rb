#!/usr/bin/env ruby
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details
#
# This will resolve the event immediately, could be used for just trigger emails or pagerduty alert
# It could also be used when testing new check. By adding an email handler or some other notiticiation, 
# the result of the check will be resolved and you will be notified without adding alerts to the UI
# and the normal alerting
#
# Could also be used together with a email handler to notify some other in the company without showing
# up in the Sensu UI, for example sending an email to customer support for some events that operation team
# shouldn't handle and don't need to know about
#
# The event resolved will not show up in database and UIs
#.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
require 'net/http'

class Resolve < Sensu::Handler

  def request(cmd)
    uri = URI.parse("http://" + settings["api"]["host"] + ":" + settings["api"]["port"].to_s + "/#{cmd}")
    http = Net::HTTP.new(uri.host, uri.port)
    request = Net::HTTP::Delete.new(uri.request_uri)
    request.add_field("content-type", "application/json")
    http.request(request)
  end


  def handle
    unless @event["status"] == 0
      request_path = "/events/#{@event['client']['name']}/#{@event['check']['name']}"
      response=request(request_path).body
      if response.code >=400 then
        raise "The response code for #{request_path} is #{response.code}"
      end
    end
  end

end
