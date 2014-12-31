#!/usr/bin/env ruby

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
require 'timeout'
require 'im-kayac'

class ImkayacNotif < Sensu::Handler
  def event_name
    @event['client']['name'] + '/' + @event['check']['name']
  end

  def event_action
    @event['action']
  end

  def handle
    user = settings['imkayac']['user']
    pass = settings['imkayac']['pass']
    message = @event['check']['notification'] || @event['check']['output']
    begin
      timeout(3) do
        p ImKayac.to("#{user}").password("#{pass}").post("#{event_action} - #{event_name} - #{message}")
      end
      rescue Timeout::Error
        puts 'im.kayac -- timed out while attempting to message'
    end
  end
end
