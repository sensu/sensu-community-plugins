#!/usr/bin/env ruby
#
# This handler creates and updates incidents and changes a component status (optional) for StatusPage.IO.
# Due to a bug with their API, please pair a Twitter account to your StatusPage even if you don't plan to tweet.
# Components only support 'major_outage' and 'operational' at this time
#
# Copyright 2011 Sonian, Inc <chefs@sonian.net>
# Copyright 2013 DISQUS, Inc.
# Updated by jfledvin with Redphone Instructions & Basic Component Support 4/5/2015
#
# NOTE: As of this writing Redphone has not added StatusPage.io support to v0.0.6
# You must manually build and install the gem:
# git clone https://github.com/portertech/redphone.git
# cd redphone
# gem build redphone.gemspec OR /opt/sensu/embedded/bin/gem build redphone.gemspec
# gem install redphone-0.0.6.gem OR /opt/sensu/embedded/bin/gem install redphone-0.0.6.gem
#
# To update a component add a "component_id": "IDHERE" attribute to the corresponding check definition

# Example:
# {
#    "checks": {
#      "check_sshd": {
#        "handlers": ["statuspage"],
#        "component_id": "IDHERE",
#        "command": "/etc/sensu/plugins/check-procs.rb -p sshd -C 1 ",
#        "interval": 60,
#        "subscribers": [ "default" ]
#      }
#    }
# }

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
      page_id: settings['statuspage']['page_id'],
      api_key: settings['statuspage']['api_key']
    )
    description = @event['notification'] || [@event['client']['name'], @event['check']['name'], @event['check']['output']].join(' : ')
    begin
      timeout(3) do
        if @event['check'].key?('component_id')
          status = case @event['action']
                   when 'create'
                     'major_outage'
                   when 'resolve'
                     'operational'
                   else
                     nil
                   end
          unless status.nil?
            statuspage.update_component(
              component_id: @event['check']['component_id'],
              status: status)
          end
        end
        response = case @event['action']
                   when 'create'
                     # #YELLOW
                     response = statuspage.create_realtime_incident( # rubocop:disable UselessAssignment, SpaceInsideParens
                       name: incident_key,
                       status: 'investigating',
                       wants_twitter_update: 'f',
                       message: "There has been a problem: #{description}."
                     )
                   when 'resolve'
                     incident_id = nil
                     statuspage.get_all_incidents.each do |incident|
                       if incident['name'] == incident_key
                         incident_id = incident['id']
                         break
                       end
                     end
                     # #YELLOW
                     response = statuspage.update_incident( # rubocop:disable UselessAssignment, SpaceInsideParens
                       name: "Problem with #{incident_key} has been resolved.",
                       wants_twitter_update: 'f',
                       status: 'resolved',
                       incident_id: incident_id
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
