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
# required. Set the nickserv_password to identify to nickserv with the
# standard Epona-services compatible:
# PRIVMSG NICKSERV :IDENTIFY <password>
# Alternately, Set the nickserv_command to specify the entire string
# to send before joining.
# An example file is contained in this irc handler directory.

#
# Copyright 2011 James Turnbull <james@lovedthanlost.net>
# Copyright 2012 AJ Christensen <aj@junglist.gen.nz>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
require 'carrier-pigeon'
require 'timeout'

class IRC < Sensu::Handler

  def event_name
    @event['client']['name'] + '/' + @event['check']['name']
  end

  def action_to_string
   @event['action'].eql?('resolve') ? "\x0300,03RESOLVED\x03" : "\x0301,04ALERT\x03"
  end

  def handle
    params = {
      :uri => settings["irc"]["irc_server"],
      :message => "#{action_to_string} #{event_name}: #{@event['check']['output']}",
      :ssl => settings["irc"]["irc_ssl"],
      :join => true,
    }
    if settings["irc"].has_key?("irc_password")
      params[:channel_password] = settings["irc"]["irc_password"]
    end

    if settings["irc"].has_key?("nickserv_command")
      params[:nickserv_command] = settings["irc"]["nickserv_command"]
    elsif settings["irc"].has_key?("nickserv_password")
      params[:nickserv_password] = settings["irc"]["nickserv_password"]
    end

    begin
      timeout(10) do
        CarrierPigeon.send(params)
        puts 'irc -- sent alert for ' + event_name + ' to IRC.'
      end
    rescue Timeout::Error
      puts 'irc -- timed out while attempting to ' + @event['action'] + ' a incident -- ' + event_name
    end
  end

end
