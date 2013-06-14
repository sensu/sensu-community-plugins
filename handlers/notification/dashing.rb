#!/usr/bin/env ruby
#
# Sensu Dashing(http://shopify.github.io/dashing/) dashboard notifier
#
# This handler sends event information to the dashing api.
#
# The handler pushes event output to widgets named following a convention of:
#  clientname-checkname
#
# For example, if you have a client named mysqlserver and a check named check_diskusage,
# it will send events to a widget with the data-id = mysqlserver-check_diskusage
#
# The event output will be pushed to the moreinfo data-bind of a widget.
#
# This works with a text dashing widget and any others that have a moreinfo data-binding.
#
# Two settings are required in dashing.json
#   auth_token  :  The shared token from you dashing instance.
#   host        :  The ip and port of the dashing instance.
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
require 'net/http'

class DashingNotifier < Sensu::Handler

  def widget
    @event['client']['name'] + '-' + @event['check']['name']
  end

  def handle
    token = settings['dashing']['auth_token']
    data = @event['check']['output']
    payload = {"auth_token" => "#{token}", "moreinfo" => "#{data}"}.to_json

    uri = URI.parse(settings['dashing']['host'])
    http = Net::HTTP.new(uri.host, uri.port)
    http.post("/widgets/#{widget}", payload)
  rescue Exception => e
    puts "Exception occured in DashingNotifier: #{e.message}", e.backtrace
  end

end
