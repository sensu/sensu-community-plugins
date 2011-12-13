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

require 'sensu-plugin/handler'
require 'carrier-pigeon'
require 'timeout'

class IRC < Sensu::Handler

  def initialize
    @settings = read_config('/etc/sensu/irc.json')
  end

  def read_config(config_file)
    if File.readable?(config_file)
      begin
        JSON.parse(File.open(config_file, 'r').read)
      rescue JSON::ParserError => e
        puts 'configuration file must be valid JSON: ' + e
      end
    else
      puts 'configuration file does not exist or is not readable: ' + config_file
    end
  end

  def handle(event)
    params = {
      :uri => @settings["irc_server"],
      :message => "#{short_name(event)}: #{event['check']['output']}",
      :ssl => @settings["irc_ssl"],
      :join => true,
    }
    if @settings.has_key?("irc_password")
      params[:channel_password] = @settings["irc_password"]
    end
    begin
      timeout(10) do
        CarrierPigeon.send(params)
        puts 'irc -- sent alert for ' + short_name(event) + ' to IRC.'
      end
    rescue Timeout::Error
      puts 'irc -- timed out while attempting to ' + event['action'] + ' a incident -- ' + short_name(event)
    end
  end

end
