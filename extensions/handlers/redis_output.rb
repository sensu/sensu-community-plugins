# Send event output to Redis
# ===
#
# Copyright 2013 kcrayon <crayon@crayon.at>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

module Sensu
  module Extension
    class RedisOutput < Handler
      def name
        'redis_output'
      end

      def description
        'sends event output to a redis list or channel'
      end

      def run(event, settings, &block)
        opts = settings["redis_output"]

        opts["db"]   ||= 0
        opts["port"] ||= 6379
        @@redis ||= Redis.connect(:host => opts["host"], :port => opts["port"], :db => opts["db"])

        output = JSON.parse(event)["check"]["output"]
        output = opts["split"] ? output.split("\n") : Array(output)

        output.each do |e|
          case opts["data_type"]
          when "list"
            @@redis.lpush(opts["key"], e)
          when "channel"
            @@redis.publish(opts["key"], e)
          end
        end

        block.call("sent #{output.count} events", 0)
      end
    end
  end
end
