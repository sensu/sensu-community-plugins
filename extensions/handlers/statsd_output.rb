# Send event output to Statsd
# ==
#
# Copyright 2013 Bethany Erskine bethany@paperlesspost.com
#
require 'statsd'

module Sensu
  module Extension
    class StastdOutput < Handler
      def name
        'statsd_output'
      end

      def description
        'sends event output to statsd'
      end

      def run(event, settings, &block)
        opts = settings['statsd_output']

        opts['statsd_host'] || "localhost"
        opts['statsd_port'] || 8125

        namespace = "sensu"
        key = "emails_sent"
        $statsd = Statsd.new(params[:statsd_host], params[:statsd_port]).tap{ 
            |sd| sd.namespace = namespace }

        $statsd.increment key

        puts "incremented counter #{namespace}.#{key}"

        block.call("sent #{output.count} events", 0)
      end
    end
  end
end
