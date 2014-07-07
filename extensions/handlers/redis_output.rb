require 'sensu/redis'

module Sensu::Extension
  class RedisOutput < Handler
    def name
      'redis_output'
    end

    def description
      'outputs events output to a redis list or channel'
    end

    def post_init
      if @settings["redis_output"].is_a?(Hash)
        @redis = Sensu::Redis.connect({
          :host => @settings["redis_output"]["host"] || 127.0.0.1,
          :port => @settings["redis_output"]["port"] || 6379,
          :database => @settings["redis_output"]["db"] || 0,
        })
      end
    end

    def run(event)
      opts = @settings["redis_output"]

      output = Oj.load(event)[:check][:output]
      output = output.split("\n") if opts["split"]

      Array(output).each do |e|
        case opts["data_type"]
        when "list"
          @redis.lpush(opts["key"], e)
        when "channel"
          @redis.publish(opts["key"], e)
        end
      end

      yield("sent #{output.count} events", 0)
    end
  end
end
