#!/usr/bin/env ruby
#
# This handler removes a Sensu client if its Chef node data
# no longer exists.
#
# Requires the following Rubygems (`gem install $GEM`):
#   - sensu-plugin
#   - spice (~> 1.0.6)
#   - rest-client
#
# Requires a Sensu configuration snippet:
#   {
#     "chef": {
#       "server_url": "https://api.opscode.com:443/organizations/vulcan",
#       "client_name": "spock",
#       "client_key": "/path/to/spocks/key.pem"
#     }
#   }
#
# Best to use this handler with a filter:
#   {
#     "filters": {
#       "keepalives": {
#         "attributes": {
#           "check": {
#             "name": "keepalive"
#           }
#         }
#       }
#     },
#     "handlers": {
#       "chef_node": {
#         "type": "pipe",
#         "command": "chef_node.rb",
#         "filter": "keepalives"
#       }
#     }
#   }
#
# Copyright 2013 Heavy Water Operations, LLC.
#
# Released under the same terms as Sensu (the MIT license); see
# LICENSE for details.

require "rubygems"
require "sensu-handler"
require "spice"
require "rest_client"
require "timeout"

class ChefNode < Sensu::Handler
  def chef_node_exists?
    Spice.setup do |s|
      s.server_url   = settings["chef"]["server_url"]
      s.client_name  = settings["chef"]["client_name"]
      s.client_key   = Spice.read_key_file(settings["chef"]["client_key"])
      s.chef_version = settings["chef"]["version"] || "11.0.0"
      unless settings["chef"]["verify_ssl"].nil?
        s.connection_options = {
          :ssl => {
            :verify => settings["chef"]["verify_ssl"]
          }
        }
      end
    end
    begin
      timeout(8) do
        !!Spice.node(@event["client"]["name"])
      end
    rescue Spice::Error::NotFound
      false
    rescue => error
      puts "Chef Node - Unexpected error: #{error.message}"
      true
    end
  end

  def delete_sensu_client!
    client_name = @event["client"]["name"]
    api_url = "http://"
    api_url << settings["api"]["host"]
    api_url << ":"
    api_url << settings["api"]["port"].to_s
    api_url << "/clients/"
    api_url << client_name
    begin
      timeout(8) do
        RestClient::Resource.new(
          api_url,
          :user     => settings["api"]["user"],
          :password => settings["api"]["password"]
        ).delete
      end
      puts "Chef Node - Successfully deleted Sensu client: #{client_name}"
    rescue => error
      puts "Chef Node - Unexpected error: #{error.message}"
    end
  end

  def filter; end

  def handle
    unless chef_node_exists?
      delete_sensu_client!
    end
  end
end
