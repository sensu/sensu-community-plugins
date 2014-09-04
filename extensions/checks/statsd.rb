# Statsd
# ===
#
# Runs a Statsd socket/implementation within the Sensu Ruby VM.
# Expects a "graphite" handler on the Sensu server, eg:
#
# "graphite": {
#   "type": "tcp",
#   "socket": {
#     "host": "graphite.hw-ops.com",
#     "port": 2003
#   },
#   "mutator": "only_check_output"
# }
#
# Copyright 2014 Heavy Water Operations, LLC.
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

module Sensu
  module Extension
    class SimpleSocket < EM::Connection
      attr_accessor :data

      def receive_data(data)
        @data << data
      end
    end

    class Statsd < Generic
      def name
        'statsd'
      end

      def description
        'a statsd implementation'
      end

      def post_init
        @flush_timers = []
        @data = EM::Queue.new
        @gauges = Hash.new { |h, k| h[k] = 0 }
        @counters = Hash.new { |h, k| h[k] = 0 }
        @timers = Hash.new { |h, k| h[k] = [] }
        @metrics = []
        setup_rabbitmq
        setup_flush_timers
        setup_parser
        setup_statsd_socket
      end

      def options
        return @options if @options
        @options = {
          :bind => '127.0.0.1',
          :port => 8125,
          :flush_interval => 10,
          :send_interval => 30,
          :percentile => 90,
          :add_client_prefix => true,
          :path_prefix => 'statsd'
        }
        if @settings[:statsd].is_a?(Hash)
          @options.merge!(@settings[:statsd])
        end
        @options
      end

      def stop
        flush!
        @flush_timers.each do |timer|
          timer.cancel
        end
        yield
      end

      private

      def setup_rabbitmq
        @rabbitmq = RabbitMQ.connect(@settings[:rabbitmq])
        @amq = @rabbitmq.channel
      end

      def add_metric(*args)
        value = args.pop
        path = []
        if options[:add_client_prefix]
          path << @settings[:client][:name]
        end
        path << options[:path_prefix]
        path = (path + args).join('.')
        if path !~ /^[A-Za-z0-9\._-]*$/
          @logger.info('invalid statsd metric', {
            :reason => 'metric path must only consist of alpha-numeric characters, periods, underscores, and dashes',
            :path => path,
            :value => value
          })
        else
          @logger.debug('adding statsd metric', {
            :path => path,
            :value => value
          })
          @metrics << [path, value, Time.now.to_i].join(' ')
        end
      end

      def flush!
        @gauges.each do |name, value|
          add_metric('guages', name, value)
        end
        @gauges.clear
        @counters.each do |name, value|
          add_metric('counters', name, value)
        end
        @counters.clear
        @timers.each do |name, values|
          values.sort!
          length = values.length
          min = values.first
          max = values.last
          mean = min
          max_at_threshold = min
          percentile = options[:percentile]
          if length > 1
            threshold_index = ((100 - percentile) / 100.0) * length
            threshold_count = length - threshold_index.round
            valid_values = values.slice(0, threshold_count)
            max_at_threshold = valid_values[-1]
            sum = 0
            valid_values.each { |v| sum += v }
            mean = sum / valid_values.length
          end
          add_metric('timers', name, 'lower', min)
          add_metric('timers', name, 'mean', mean)
          add_metric('timers', name, 'upper', max)
          add_metric('timers', name, 'upper_' + percentile.to_s, max_at_threshold)
        end
        @timers.clear
        @logger.debug('flushed statsd metrics')
      end

      def send!
        unless @metrics.empty?
          payload = {
            :client => @settings[:client][:name],
            :check => {
              :name => 'statsd',
              :type => 'metric',
              :status => 0,
              :output => @metrics.join("\n") + "\n",
              :handler => 'graphite'
            }
          }
          @logger.info('sending statsd metrics to graphite', {
            :count => @metrics.count
          })
          @metrics = []
          @amq.direct('results').publish(Oj.dump(payload))
        end
      end

      def setup_flush_timers
        @flush_timers << EM::PeriodicTimer.new(options[:flush_interval]) do
          flush!
        end
        @flush_timers << EM::PeriodicTimer.new(options[:send_interval]) do
          send!
        end
      end

      def setup_parser
        parser = Proc.new do |data|
          begin
            nv, type = data.strip.split('|')
            name, value = nv.split(':')
            case type
            when 'g'
              @gauges[name] = Float(value)
            when /^c/, 'm'
              _, raw_sample = type.split('@')
              sample = (raw_sample ? Float(raw_sample) : 1)
              @counters[name] += Integer(value) * (1 / sample)
            when 'ms', 'h'
              @timers[name] << Float(value)
            end
          rescue => error
            @logger.error('statsd parser error', {
              :error => error.to_s
            })
          end
          EM.next_tick do
            @data.pop(&parser)
          end
        end
        @data.pop(&parser)
      end

      def setup_statsd_socket
        @logger.debug('binding statsd tcp and udp sockets', {
         :options => options
        })
        bind = options[:bind]
        port = options[:port]
        EM.start_server(bind, port, SimpleSocket) do |socket|
          socket.data = @data
        end
        EM.open_datagram_socket(bind, port, SimpleSocket) do |socket|
          socket.data = @data
        end
      end
    end
  end
end
