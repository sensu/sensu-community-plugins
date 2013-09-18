#!/usr/bin/env ruby
#
# This handler removes Sensu client if it has been terminated in EC2.
#
# NOTE: The implementation for correlating Sensu clients to EC2 instances may
# need to be modified to fit your organization. The current implementation
# assumes that Sensu clients' names are the same as their instance IDs in EC2.
# If this is not the case, you can either sub-class this handler and override
# `ec2_node_exists?` in your own organization-specific handler, or modify this
# handler to suit your needs.
#
# Requires the following Rubygems (`gem install $GEM`):
#   - sensu-plugin
#   - fog
#
# Requires the following environment variables to be set:
#   - AWS_ACCESS_KEY_ID
#   - AWS_SECRET_ACCESS_KEY
#   - EC2_REGION
#
# Or you can use a Sensu configuration snippet:
#   {
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
#       "ec2_node": {
#         "type": "pipe",
#         "command": "/etc/sensu/handlers/ec2_node.rb",
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
#         "handler": "ec2_node"
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
require 'fog'

class Ec2Node < Sensu::Handler

  def filter; end

  def handle
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

end
