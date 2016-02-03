#
# Sensu Logstash Extension
#
# Heavily inspried (er, copied from) the flapjack extension, hipchat
# extension and original logstash handler writeen by Zach Dunn.
#
# Designed to take sensu events, transform them into logstah JSON events
# and ship them to a redis server for logstash to index.
#
# Written by Zdenek Janda -- @ZdenekJanda or http://github.com/zdenekjanda
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'sensu/redis'
require 'socket'
require 'time'
require 'timeout'
require 'net/http'

module Sensu
  module Extension
    class Logstash < Handler
      def name
        'logstash'
      end

      def description
        'sends sensu events to the logstash redis queue'
      end

      def options
        return @options if @options
        @options = {
          host:    '127.0.0.1',
          port:    6379,
          channel: 'sensu:logstash',
          db:      0
        }
        if @settings[:logstash].is_a?(Hash)
          @options.merge!(@settings[:logstash])
        end
        @options
      end

      def definition
        {
          type:    'extension',
          name:    name,
          mutator: 'ruby_hash'
        }
      end

      def post_init
        @redis = Sensu::Redis.connect(options)
        @redis.on_error do |_error|
          @logger.warn('Logstash handler: Redis instance not available on ' + options[:host])
        end
      end

      def send_redis(logstash_event)
        @redis.lpush(options[:channel], MultiJson.dump(logstash_event))
      end

      # Log something and return false.
      def bail(msg, event)
        @logger.info("Logstash handler: #{msg}: #{event[:client][:name]}/#{event[:check][:name]}")
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
          'interval' => 60,
          'refresh' => 1800
        }
        occurrences = event[:check][:occurrences] || defaults['occurrences']
        interval = event[:check][:interval] || defaults['interval']
        refresh = event[:check][:refresh] || defaults['refresh']
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
            @logger.warn('Logstash handler: Timed out while attempting to query the sensu api for a stash')
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
              @logger.warn('Logstash handler: Timed out while attempting to query the sensu api for an event')
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
        true
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

      def run(event)
        # Is this event a resolution?
        resolved = event[:action].eql?(:resolve)

        # If this event is resolved, or in one of the 'bad' states, and it passes all the filters,
        # send the message to hipchat
        if (resolved || [1, 2, 3].include?(event[:check][:status])) && filters(event)
          client = event[:client]
          check = event[:check]
          state = check[:status]
          state_msg, _color, _notify = clarify_state(state, check)
          status_msg = event[:action].to_s.upcase.to_s
          tags = []
          tags.concat(client[:tags]) if client[:tags].is_a?(Array)
          tags.concat(check[:tags]) if check[:tags].is_a?(Array)
          tags << client[:environment] unless client[:environment].nil?
          if !check[:subscribers].nil? || !check[:subscribers].empty?
            tags.concat(client[:subscriptions] - (client[:subscriptions] - check[:subscribers]))
          else
            tags.concat(client[:subscriptions])
          end
          details = ['Address:' + client[:address]]
          details << 'Tags:' + tags.join(',')
          details << "Raw Output: #{check[:output]}" if check[:notification]

          time = Time.now.utc.iso8601
          logstash_event = {
            type:        'sensu',
            source:      ::Socket.gethostname,
            message:     check[:notification] || check[:output],
            host:        client[:name],
            issued:      check[:issued],
            executed:    check[:executed],
            address:     client[:address],
            check:       check[:name],
            command:     check[:command],
            status:      Sensu::SEVERITIES[check[:status]] || 'unknown',
            action:      event[:action],
            occurrences: check[:occurrences],
            interval:    check[:interval],
            refresh:     check[:refresh],
            state_msg:   state_msg,
            status_msg:  status_msg,
            tags:        tags,
            level:       6
          }
          logstash_event[:@timestamp] = time
          logstash_event[:@version]   = 1
          send_redis(logstash_event)
          yield 'Logstash handler: Sent an event to the logstash redis queue', 0
        end
      end
    end
  end
end
