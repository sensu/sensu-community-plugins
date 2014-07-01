#!/usr/bin/env ruby
#
# Sensu Twitter Handler
# =====================
#
# The functionality of this handler is the same as twitter.rb however supports the latest Twitter gem.
# 99% based on the original work by Joe Crim.
#
# This handler reports alerts to a configured twitter handler.
# Map a twitter handle to a sensusub value in the twitter.json to get going!
# sensusub == subscription in the client object, not check..
# see twitter.json for required values
#
# Copyright 2011 Joe Crim <josephcrim@gmail.com>
# Modifications 2014 Matt Johnson <matjohn2@cisco.com>
#
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
require 'twitter'
require 'timeout'

class TwitterHandler < Sensu::Handler

  def event_name
    @event['client']['name'] + '/' + @event['check']['name']
  end

  def handle
    puts settings['twitter']
    settings['twitter'].each do |account|
      if @event['client']['subscriptions'].include?(account[1]["sensusub"])
        tclient = Twitter::REST::Client.new do |t|
          t.consumer_key = account[1]["consumer_key"]
          t.consumer_secret = account[1]["consumer_secret"]
          t.access_token = account[1]["oauth_token"]
          t.access_token_secret = account[1]["oauth_token_secret"]
        end
        if @event['action'].eql?("resolve")
          tclient.update("RESOLVED - #{event_name}: #{@event['check']['notification']} Time: #{Time.now} ")
        else
          tclient.update("ALERT - #{event_name}: #{@event['check']['notification']} Time: #{Time.now} ")
        end
      end
    end
  end

end
