# Sends events to Flapjack for notification routing. See http://flapjack.io/
#
# In order for Flapjack to keep its entities up to date, it is necssary to set
# metric to "true" for each check that is using the flapjack handler.
#
# Here is an example of what the Sensu configuration for flapjack should
# look like, assuming your Flapjack's redis service is running on the same server
# as Sensu:
#
# {
#   "flapjack": {
#      "host": "localhost",
#      "port": 6379,
#      "db": "0"
#   }
# }
#
# Copyright 2014 Jive Software and contributors.
#
# Released under the same terms as Sensu (the MIT license); see LICENSE for details.

require 'json'
require 'rubygems'
require 'sensu/redis'

module Sensu::Extension
  class Flapjack < Handler
    def name
      'flapjack'
    end

    def description
      'outputs events to the flapjack redis database'
    end

    def post_init
      @redis = Sensu::Redis.connect({
        :host => @settings[:flapjack]["host"] || '127.0.0.1',
        :port => @settings[:flapjack]["port"] || 6379,
        :channel => @settings[:flapjack]["channel"] || 'events',
        :database => @settings[:flapjack]["db"] || 0,
      })
      # For now we want sensu to start even if the flapjack redis instance
      # is not available.
      @redis.on_error do |error|
        @logger.warn("Flapjack redis instance not available on #{@settings[:flapjack]["host"]}")
      end
    end

    def run(event)
      event = Oj.load(event)
      state = event[:check][:status]
      check_state = case state
      when 0
        'ok'
      when 1
        'warning'
      when 2
        'critical'
      else
        'unknown'
      end
      timestamp = event[:check][:issued]
      entity = event[:client][:name]
      check = event[:check][:name]
      check_output = event[:check][:output]
      details = ''

      begin
        check_output = JSON.parse(check_output)
        check_output_parsed = ''
        check_output.each do |line|
          check_output_parsed << "#{line['name']}=#{line['value']} "
        end
        check_output = check_output_parsed
      rescue
        check_output_parsed = check_output
      end

      event = {
        'entity'    => entity,
        'check'     => check,
        'type'      => 'service',
        'state'     => check_state,
        'summary'   => check_output_parsed.to_s,
        'details'   => details,
        'time'      => timestamp,
      }

      @redis.lpush('events', event.to_json)

      yield("sent flapjack event", 0)
    end
  end
end
