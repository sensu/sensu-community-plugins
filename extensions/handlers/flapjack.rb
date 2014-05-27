# Sends events to Flapjack for notification routing. See http://flapjack.io/
#
# This extension requires Flapjack >= 0.8.7
#
# In order for Flapjack to keep its entities up to date, it is necssary to set
# metric to "true" for each check that is using the flapjack handler extension.
#
# Here is an example of what the Sensu configuration for flapjack should
# look like, assuming your Flapjack's redis service is running on the
# same machine as the Sensu server:
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

module Sensu
  module Extension
    class Flapjack < Handler
      def name
        'flapjack'
      end

      def description
        'sends sensu events to the flapjack redis queue'
      end

      def options
        return @options if @options
        @options = {
          :host    => '127.0.0.1',
          :port    => 6379,
          :channel => 'events',
          :db      => 0
        }
        if @settings[:flapjack].is_a?(Hash)
          @options.merge!(@settings[:flapjack])
        end
        @options
      end

      def post_init
        @redis = Sensu::Redis.connect(options)
        @redis.on_error do |error|
          @logger.warn('Flapjack Redis instance not available on ' + options[:host])
        end
      end

      def run(event_data)
        event = Oj.load(event_data)
        client = event[:client]
        check = event[:check]
        tags = []
        tags << client[:environment] unless client[:environment].nil?
        unless check[:subscribers].nil? || check[:subscribers].empty?
          tags.concat(client[:subscriptions] - (client[:subscriptions] - check[:subscribers]))
        else
          tags.concat(client[:subscriptions])
        end
        unless check[:flapjack_tags].nil? || check[:flapjack_tags].empty?
          tags.concat(check[:flapjack_tags])
        end
        details = ['Address:' + client[:address]]
        details << 'Tags:' + tags.join(',')
        flapjack_event = {
          :entity  => client[:name],
          :check   => check[:name],
          :type    => 'service',
          :state   => Sensu::SEVERITIES[check[:status]] || 'unknown',
          :summary => check[:output],
          :details => details.join(' '),
          :time    => check[:executed],
          :tags    => tags
        }
        @redis.lpush(options[:channel], Oj.dump(flapjack_event))
        yield 'sent an event to the flapjack redis queue', 0
      end
    end
  end
end
