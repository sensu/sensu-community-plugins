module Sensu::Extension
  class RedisOutput < Handler
    def definition
      {
        type: 'extension',
        name: 'redis_output',
      }
    end

    def name
      definition[:name]
    end

    def description
      'outputs events output to a redis list or channel'
    end

    def run(event)
      opts = @settings["redis_output"]

      opts["db"]   ||= 0
      opts["port"] ||= 6379
      @redis ||= Sensu::Redis.connect(:host => opts["host"], :port => opts["port"], :db => opts["db"])

      output = Oj.load(event)[:check][:output]
      output = opts["split"] ? output.split("\n") : Array(output)

      output.each do |e|
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
