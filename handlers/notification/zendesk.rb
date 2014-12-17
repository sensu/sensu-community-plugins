#!/usr/bin/env ruby
#
# Sensu Zendesk Handler
#
# DESCRIPTION:
#  Handler to automatic create new tickets in Zendesk for alarms.
#
#  subscriptions_to_tags - transforms your subscriptions in tags
#  status_to_use - determine if Critical (2), Warning (1) or Unknown (3) alerts will create tickets
#
# OUTPUT:
#   Create a new Zendesk ticket
#
# PLATFORMS:
#   all
#
# DEPENDENCIES:
#  gem zendesk_api
#
# 2014, Diogo Gomes <diogo.gomes@ideais.com.br> @_diogo
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
require 'zendesk_api'

class Zendesk < Sensu::Handler
  def handle
    client = ZendeskAPI::Client.new do |config|
      config.url = settings['zendesk']['url']

      # Basic / Token Authentication
      config.username = settings['zendesk']['username']

      # Choose one of the following depending on your authentication choice
      # #YELOW
      unless settings['zendesk']['token'].nil? # rubocop:disable UnlessElse
        config.token = settings['zendesk']['token']
      else
        config.password = settings['zendesk']['password']
      end
      config.retry = true
    end

    def ticket_subject
      'Alert - ' + @event['client']['name'] + ' - ' + @event['check']['name']
    end

    def ticket_description
      "Sensu Alert\r\n" \
          'Client: ' + @event['client']['name'] + "\r\n" \
          'Address: ' + @event['client']['address'] + "\r\n" \
          'Subscriptions: ' + @event['client']['subscriptions'].join(', ') + "\r\n" \
          'Check: ' + @event['check']['name'] + "\r\n" \
          'Output: ' + @event['check']['output'] + "\r\n"
    end

    def ticket_tags
      tags = []
      unless settings['zendesk']['tags'].nil?
        tags << settings['zendesk']['tags']
      end
      if settings['zendesk']['subscriptions_to_tags']
        tags << @event['client']['subscriptions']
      end
      tags
    end

    begin
      timeout(60) do
        if settings['zendesk']['status_to_use'].include?(@event['check']['status'])
          ZendeskAPI::Ticket.create(
              client,
              subject: ticket_subject,
              comment: { value: ticket_description },
              submitter_id: client.current_user.id,
              priority: settings['zendesk']['priority'] || 'urgent',
              type: settings['zendesk']['type'] || 'incident',
              tags: ticket_tags
          )
        end
      end
  rescue Timeout::Error
    puts 'zendesk -- timed out while attempting to create a ticket for #{ticket_subject} --'
    end
  end
end
