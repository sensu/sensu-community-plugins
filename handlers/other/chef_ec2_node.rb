#!/usr/bin/env ruby
#
# This handler removes a Chef node if it has been terminated in EC2 by means
# that do not remove the information from the Chef Server, such as through the
# EC2 web console.
#
# NOTE: The implementation for correlating Sensu clients to Chef nodes in EC2
# may need to be modified to fit your organization. The current implementation
# assumes that Sensu clients' names are the same as their instance IDs in EC2.
# If this is not the case, you can either sub-class this handler and override
# `ec2_node_exists?` in your own organization-specific handler, or modify this
# handler to suit your needs.
#
# Requires the following Rubygems (`gem install $GEM`):
#   - sensu-plugin
#   - spice (~> 1.0.6)
#   - fog
#
# Requires the following environment variables to be set:
#   - AWS_ACCESS_KEY_ID
#   - AWS_SECRET_ACCESS_KEY
#
# Requires a Sensu configuration snippet:
#   {
#     "chef": {
#       "server_url": "https://api.opscode.com:443/organizations/vulcan",
#       "client_name": "spock",
#       "client_key": "/path/to/spocks/key.pem",
#       "version": "10.16.4",
#       "verify_ssl": false
#     }
#   }
#
# You can use this handler with a filter:
#   {
#     "filters": {
#       "ghost_nodes": {
#         "attributes": {
#           "check": {
#             "name": "keepalive"
#           },
#           "occurences": "eval: value > 2"
#         }
#       }
#     },
#     "handlers": {
#       "chef_ec2_node": {
#         "type": "pipe",
#         "command": "/etc/sensu/handlers/chef_ec2_node.rb",
#         "filter": "ghost_nodes"
#       }
#     }
#   }
#
# You could also use it by assigning it as (one of) the keepalive handler(s) for
# clients:
#   {
#     "client": {
#       "name": "i-424242",
#       "address": "127.0.0.1",
#       "keepalive": {
#         "handler": "chef_ec2_node"
#       },
#       "subscriptions": ["all"]
#     }
#   }
#
# Copyleft 2013 Yet Another Clever Name
#
# Based off of the `chef_node` handler by Heavy Water Operations, LLC
#
# Released under the same terms as Sensu (the MIT license); see
# LICENSE for details

require 'timeout'
require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
require 'spice'
require 'fog'

class ChefEc2Node < Sensu::Handler

  def initialize
    setup_spice
  end

  def filter; end

  def handle
    if chef_node_exists?
      delete_chef_node! unless ec2_node_exists?
    end
  end

  def chef_node_exists?
    begin
      timeout(8) do
        !!Spice.node(@event['client']['name'])
      end
    rescue Spice::Error::NotFound
      false
    rescue => error
      puts "Chef Ec2 Node - Unexpected error: #{error.message}"
      true
    end
  end

  def ec2_node_exists?
    ec2 = Fog::Compute.new({
      :provider => 'AWS',
      :aws_access_key_id => ENV['AWS_ACCESS_KEY_ID'],
      :aws_secret_access_key => ENV['AWS_SECRET_ACCESS_KEY']
    })
    running_instances = ec2.servers.reject { |s| s.state == 'terminated' }
    instance_ids = running_instances.collect { |s| s.id }
    instance_ids.each do |id|
      return true if id == @event['client']['name']
    end
    return false # no match found, node doesn't exist
  end

  def delete_chef_node!
    cmd = "/nodes/#{@event['client']['name']}"
    Spice.delete(cmd)
  end

  def setup_spice
    Spice.setup do |s|
      s.server_url   = settings['chef']['server_url']
      s.client_name  = settings['chef']['client_name']
      s.client_key   = Spice.read_key_file(settings['chef']['client_key'])
      s.chef_version = settings['chef']['version'] || '11.0.0'
      unless settings['chef']['verify_ssl'].nil?
        s.connection_options = {
          :ssl => {
            :verify => settings['chef']['verify_ssl']
          }
        }
      end
    end
  end

end
