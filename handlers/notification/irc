#!/usr/bin/env ruby
#
# Sensu IRC Handler
# ===
#
# This handler reports alerts to a specified IRC channel. You need to
# set the options in the irc.json configuration file, located by default
# in /etc/sensu. Set the irc_server option to control the IRC server to
# connect to, the irc_password option to set an optional channel
# password and the irc_ssl option to true to enable an SSL connection if
# required. An example file is contained in this irc handler directory.
#
# Copyright 2011 James Turnbull
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
require 'carrier-pigeon'
require 'timeout'

class IRC < Sensu::Handler

  def short_name
    @event['client']['name'] + '/' + @event['check']['name']
  end

  def handle
    params = {
      :uri => settings["irc"]["irc_server"],
      :message => "#{short_name(@event)}: #{@event['check']['output']}",
      :ssl => settings["irc"]["irc_ssl"],
      :join => true,
    }
    if settings["irc"].has_key?("irc_password")
      params[:channel_password] = settings["irc"]["irc_password"]
    end
    begin
      timeout(10) do
        CarrierPigeon.send(params)
        puts 'irc -- sent alert for ' + short_name(@event) + ' to IRC.'
      end
    rescue Timeout::Error
      puts 'irc -- timed out while attempting to ' + @event['action'] + ' a incident -- ' + short_name(@event)
    end
  end

end
