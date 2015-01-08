#!/usr/bin/env ruby
#
# Sensu Flowdock (https://www.flowdock.com/api/chat) notifier
# This handler sends event information to the Flowdock Push API: Chat.
# The handler pushes event output to chat:
# This setting is required in flowdock.json
#   auth_token  :  The flowdock api token (flow_api_token)
#
# Dependencies
# -----------
# - flowdock
#
#
# Author Ramez Hanna <rhanna@informatiq.org>

# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
require 'flowdock'

class FlowdockNotifier < Sensu::Handler
  def handle
    token = settings['flowdock']['auth_token']
    data = @event['check']['output']
    flow = Flowdock::Flow.new(api_token: token, external_user_name: 'Sensu')
    flow.push_to_chat(content: data, tags: %w(sensu test))
  end
end
