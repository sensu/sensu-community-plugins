require 'sensu/redis'

# #YELLOW
module Sensu::Extension # rubocop:disable Style/ClassAndModuleChildren
  class RedisOutput < Handler
    def name
      'redis_output'
    end

    def description
      'outputs events output to a redis list or channel'
    end

    def opts
      @settings['redis_output']
    end

    def post_init
      @redis = Sensu::Redis.connect(host: opts['host'],
                                    port: opts['port'] || 6379,
                                    database: opts['db'] || 0)
    end

    def run(event)
      output = Oj.load(event, symbol_keys: false)['check']['output']
      output = opts['split'] ? output.split("\n") : Array(output)

      case opts['data_type']
      when 'list'
        output.each { |e| @redis.lpush(opts['key'], e) }
      when 'channel'
        output.each { |e| @redis.publish(opts['key'], e) }
      end

      yield("sent #{output.count} events", 0)
    end
  end
end
