#!/usr/bin/env ruby
#
# Sensu Twitter Handler
# ===
#
# This handler reports alerts to a configured twitter handler. 
# Map a twitter handle to a sensusub value in the twitter.json to get going!
# sensusub == subscription in the client object, not check..
# see twitter.json for required values
#
# Copyright 2011 Joe Crim
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'sensu-handler'
require 'twitter'
require 'timeout'

class TwitterHandler < Sensu::Handler

  def initialize
    @settings = read_config('/etc/sensu/twitter.json')
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
    puts @settings
    @settings.each do |account|
      if event['client']['subscriptions'].include?(account[1]["sensusub"])
        Twitter.configure do |config|
          config.consumer_key = account[1]["consumer_key"]
          config.consumer_secret = account[1]["consumer_secret"]
          config.oauth_token = account[1]["oauth_token"]
          config.oauth_token_secret = account[1]["oauth_token_secret"]
        end
        if event['action'].eql?("resolve")
          Twitter.update("RESOLVED - #{short_name(event)}: #{event['check']['notification']} Time: #{Time.now()} ")
        else
          Twitter.update("ALERT - #{short_name(event)}: #{event['check']['notification']} Time: #{Time.now()} ")
        end
      end
    end
  end
  
end