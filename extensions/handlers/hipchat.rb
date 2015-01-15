#!/usr/bin/env ruby
#
# Sends events to hipchat for wonderful chatty notifications
#
# This extension requires the hipchat gem
#
# The reason I wrote this instead of using the normal hipchat handler, is that with Flapjack
# all events are handled unless you do crazy filtering stuff. Also with a large number of events
# and checks the sensu server can get overloaded with forking stuff. So anyway, hipchat extension :)
#
# Here is an example of what the Sensu configuration for hipchat should
# look like. It's fairly configurable:
#
# {
#   "hipchat": {
#     "apiversion": "v2",
#     "room": "room api id number",
#     "room_api_token": "room notification token",
#     "from": "Sensu",
#     "keepalive": {
#       "room": "room api id number",
#       "occurrences": {hipchat_keepalive_occurrences}
#     }
#   }
# }
#
# The first four variables should be fairly self-explanatory.
# The 'keepalive' block is for keepalive check settings, in case you want to have keepalive alerts
# going to a different room, repeating at different intervals. This could probably be done better.
#
# Checks can also define a hipchat room, and other options.
# Options that can be passed in event data are as follows:
#   "hipchat_room"   => Room to send hipchat events for this check to
#   "hipchat_from"   => Name to send message from (defaults to Sensu)
#   "hipchat_notify" => Turn on/off the hipchat 'notify' option (defines if the room goes red on new message)
#    - Defaults to 'true' for OK, Critical, Warning and 'false' for Unknown
#   "playbook"       => URL or HTML for playbook for that check
#
# Copyright 2014 Steve Berryman and contributors.
#
# 10/01/2014 - Alan Smith
# Trimmed out Slack stuff and got resolve events sending again.
#
# Released under the same terms as Sensu (the MIT license); see LICENSE for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'hipchat'
require 'timeout'
require 'net/http'

# #YELLOW
module Sensu::Extension # rubocop:disable Style/ClassAndModuleChildren
  class Hipchat < Handler
    # The post_init hook is called after the main event loop has started
    # At this time EventMachine is available for interaction.
    def post_init
    end

    # Must at a minimum define type and name. These are used by
    # Sensu during extension initialization.
    def definition
      {
        type: 'extension',  # Always.
        name: 'hipchat',   # Usually just class name lower case.
        mutator: 'ruby_hash'
      }
    end

    # Simple accessor for the extension's name. You could put a different
    # value here that is slightly more descriptive, or you could simply
    # refer to the definition name.
    def name
      definition[:name]
    end

    # A simple, brief description of the extension's function.
    def description
      'Hipchat extension. Because otherwise the sensu server will forking die.'
    end

    # Sends an event to the specified hipchat room etc
    def send_hipchat(room, from, message, color, notify)
      apiversion = @settings['hipchat']['apiversion'] || 'v1'
      room_api_token = @settings['hipchat']['room_api_token']

      hipchatmsg = HipChat::Client.new(room_api_token, api_version: apiversion)

      begin
        timeout(3) do
          hipchatmsg[room].send(from, "#{message}.", color: color, notify: notify)
          return 'Sent hipchat message'
        end
      rescue Timeout::Error
        return "Timed out while attempting to message #{room} [#{message}]"
      rescue HipChat::UnknownResponseCode
        return 'Hipchat returned an unknown response code (rate limited?)'
      end
    end

    # Log something and return false.
    def bail(msg, event)
      @logger.info("Hipchat handler: #{msg}: #{event[:client][:name]}/#{event[:check][:name]}")
      false
    end

    # Lifted from the sensu-plugin gem, makes an api request to sensu
    def api_request(method, path, &_blk)
      http = Net::HTTP.new(@settings['api']['host'], @settings['api']['port'])
      req = net_http_req_class(method).new(path)
      if @settings['api']['user'] && @settings['api']['password']
        req.basic_auth(@settings['api']['user'], @settings['api']['password'])
      end
      yield(req) if block_given?
      http.request(req)
    end

    # also lifted from the sensu-plugin gem. In fact, most of the rest was.
    def net_http_req_class(method)
      case method.to_s.upcase
      when 'GET'
        Net::HTTP::Get
      when 'POST'
        Net::HTTP::Post
      when 'DELETE'
        Net::HTTP::Delete
      when 'PUT'
        Net::HTTP::Put
      end
    end

    def stash_exists?(path)
      api_request(:GET, '/stash' + path).code == '200'
    end

    def event_exists?(client, check)
      api_request(:GET, '/event/' + client + '/' + check).code == '200'
    end

    # Has this check been disabled from handlers?
    def filter_disabled(event)
      if event[:check].key?(:alert)
        bail 'alert disabled', event if event[:check][:alert] == false
      end

      true
    end

    # Don't spam hipchat too much!
    def filter_repeated(event)
      defaults = {
        'occurrences' => 1,
        'interval'    => 60,
        'refresh'     => 1800
      }

      occurrences = event[:check][:occurrences] || defaults['occurrences']
      interval    = event[:check][:interval]    || defaults['interval']
      refresh     = event[:check][:refresh]     || defaults['refresh']

      return bail 'not enough occurrences', event if event[:occurrences] < occurrences

      if event[:occurrences] > occurrences && event[:action] == :create
        number = refresh.fdiv(interval).to_i
        unless number == 0 || event[:occurrences] % number == 0
          return bail 'only handling every ' + number.to_s + ' occurrences', event
        end
      end

      true
    end

    # Has the event been silenced through the API?
    def filter_silenced(event)
      stashes = [
        ['client', '/silence/' + event[:client][:name]],
        ['check', '/silence/' + event[:client][:name] + '/' + event[:check][:name]],
        ['check', '/silence/all/' + event[:check][:name]]
      ]
      stashes.each do |(scope, path)|
        begin
          timeout(2) do
            return bail scope + ' alerts silenced', event if stash_exists?(path)
          end
        rescue Timeout::Error
          @logger.warn('timed out while attempting to query the sensu api for a stash')
        end
      end

      true
    end

    # Does this event have dependencies?
    def filter_dependencies(event)
      if event[:check].key?(:dependencies) && event[:check][:dependencies].is_a?(Array)
        event[:check][:dependencies].each do |dependency|
          begin
            timeout(2) do
              check, client = dependency.split('/').reverse
              if event_exists?(client || event[:client][:name], check)
                return bail 'check dependency event exists', event
              end
            end
          rescue Timeout::Error
            @logger.warn('timed out while attempting to query the sensu api for an event')
          end
        end
      end

      true
    end

    # Run all the filters in some order. Only run the handler if they all return true
    def filters(event_data)
      return false unless filter_repeated(event_data)
      return false unless filter_silenced(event_data)
      return false unless filter_dependencies(event_data)
      return false unless filter_disabled(event_data)

      @logger.info("#{event_data[:client][:name]}/#{event_data[:check][:name]} not being filtered!")

      true
    end

    def color_to_hex(color)
      if color == 'green'
        '#09B524'
      elsif color == 'red'
        '#E31717'
      elsif color == 'yellow'
        '#FFFF00'
      else
        '#FFFFFF'
      end
    end

    def build_link(url, text)
      "<a href='#{url}'>#{text}</a>"
    end

    def build_playbook(check)
      # If the playbook attribute exists and is a URL, "[<a href='url'>playbook</a>]" will be output.
      # To control the link name, set the playbook value to the HTML output you would like.
      if check[:playbook]
        begin
          uri = URI.parse(check[:playbook])
          if %w( http https ).include?(uri.scheme)
            "[#{build_link(check[:playbook], 'Playbook')}]"
          else
            "Playbook:  #{check[:playbook]}"
          end
        rescue
          "Playbook:  #{check[:playbook]}"
        end
      else
        nil
      end
    end

    def build_hipchat_message(event, state_msg, status_msg)
      check = event[:check]
      client_name = check[:source] || event[:client][:name]
      check_name = check[:name]
      output = check[:notification] || check[:output]
      playbook = build_playbook(check)

      "#{status_msg} #{client_name}/#{check_name} - #{state_msg}: #{output} #{playbook}"
    end

    def clarify_state(state, check)
      if state == 0
        state_msg = 'OK'
        color = 'green'
        notify = check[:hipchat_notify] || true
      elsif state == 1
        state_msg = 'WARNING'
        color = 'yellow'
        notify = check[:hipchat_notify] || true
      elsif state == 2
        state_msg = 'CRITICAL'
        color = 'red'
        notify = check[:hipchat_notify] || true
      else
        state_msg = 'UNKNOWN'
        color = 'gray'
        notify = check[:hipchat_notify] || false
      end

      [state_msg, color, notify]
    end

    # run() is passed a copy of the event_data hash
    def run(event_data)
      event = event_data
      # Is this event a resolution?
      resolved = event[:action].eql?(:resolve)

      # Is this event a keepalive?
      # Adding extra config on every client is annoying. Just make some extra settings for it.
      keepalive = @settings['hipchat']['keepalive'] || {}
      if event[:check][:name] == 'keepalive'
        event[:check][:occurrences] = keepalive['occurrences'] || 6
        event[:check][:hipchat_room] = keepalive['room'] || @settings['hipchat']['room']
        event[:check][:hipchat_from] = keepalive['from'] || @settings['hipchat']['from'] || 'Sensu'
      end

      # If this event is resolved, or in one of the 'bad' states, and it passes all the filters,
      # send the message to hipchat
      if (resolved || [1, 2, 3].include?(event[:check][:status])) && filters(event)
        check = event[:check]

        room = check[:hipchat_room] || @settings['hipchat']['room']
        from = check[:hipchat_from] || @settings['hipchat']['from'] || 'Sensu'
        state = check[:status]
        state_msg, color, notify = clarify_state(state, check)
        status_msg = "#{event[:action].to_s.upcase}:"

        hipchat_msg = build_hipchat_message(event, state_msg, status_msg)

        operation = proc { send_hipchat(room, from, hipchat_msg, color, notify) }
        callback = proc { |result| yield "Hipchat message: #{result}", 0 }

        EM.defer(operation, callback)
      else
        yield 'Hipchat not handling', 0
      end
    end

    # Called when Sensu begins to shutdown.
    def stop
      true
    end
  end
end
