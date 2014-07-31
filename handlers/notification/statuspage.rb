#!/usr/bin/env ruby
#
# This handler creates and updates incidents for StatusPage.IO.
# Due to a bug with their API, please pair a Twitter account to your StatusPage even if you don't plan to tweet.
#
# Copyright 2011 Sonian, Inc <chefs@sonian.net>
# Copyright 2013 DISQUS, Inc.
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
require 'redphone/statuspage'

class StatusPage < Sensu::Handler

  def incident_key
    @event['client']['name'] + '/' + @event['check']['name']
  end

  def handle
    statuspage = Redphone::Statuspage.new(
      :page_id => settings['statuspage']['page_id'],
      :api_key => settings['statuspage']['api_key']
    )
    description = @event['notification'] || [@event['client']['name'], @event['check']['name'], @event['check']['output']].join(' : ')
    begin
      timeout(3) do
        response = case @event['action']
                   when 'create'
                    response = statuspage.create_realtime_incident(# rubocop:disable UselessAssignment
                      :name => incident_key,
                      :status => "investigating",
                      :wants_twitter_update => "f",
                      :message => "There has been a problem: #{description}."
                    )
                    when 'resolve'
                      incident_id = nil
                      statuspage.get_all_incidents.each do |incident|
                        if incident['name'] == incident_key
                          incident_id = incident['id']
                          break
                        end
                      end
                      response = statuspage.update_incident(# rubocop:disable UselessAssignment
                        :name => "Problem with #{incident_key} has been resolved.",
                        :wants_twitter_update => "f",
                        :status => "resolved",
                        :incident_id => incident_id
                      )
                   end
        if (response['status'] == 'investigating' || @event['action'] == 'create') || (response['status'] == 'resolved' || @event['action'] == 'resolve')
          puts 'statuspage -- ' + @event['action'].capitalize + 'd incident -- ' + incident_key
        else
          puts 'statuspage -- failed to ' + @event['action'] + ' incident -- ' + incident_key
        end
      end
    rescue Timeout::Error
      puts 'statuspage -- timed out while attempting to ' + @event['action'] + ' a incident -- ' + incident_key
    end

  end

end
