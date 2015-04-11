# Graphite data check
#
# Checks that graphite metrics are within expected values
#
# REQUIRES SENSU 0.17.1 or HIGHER
#
# Usage
# {
#   "checks": {
#     "check_graphite": {
#       "extension": "check_graphite",
#       "subscribers": [],
#       "handlers": [
#         "default"
#       ],
#       "interval": 20,
#       "check_graphite": {
#         "target": "servers.node1.cpu-0.cpu-idle", #required
#         "server": "graphite.server.com", #required
#         "critical": 90, #optional
#         "warning": 50, #optional
#         "username": "user", #optional
#         "password": "pass", #optional
#         "allowed_graphite_age": 60, #optional
#         "from": "-10min', #optional
#         "below": false, #optional
#         "no_ssl_verify": false, #optional
#       }
#     }
#   }
# }
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'net/http'
require 'open-uri'
require 'openssl'
require 'json'

class ThresholdReached < StandardError
end
class ThresholdReachedCritical < StandardError
end
class ThresholdReachedWarning < StandardError
end
class AgeThresholdReached < StandardError
end

module Sensu
  module Extension
    class GraphiteCheck < Check
      def name
        'check_graphite'
      end

      def description
        'checks graphite metrics'
      end

      def definition
        {
          type: 'check',
          name: name,
          standalone: false,
          handler: options[:handler]
        }
      end

      def post_init
        true
      end

      def run(check)
        unless check_options check
          yield 'MISSING CONFIG PARAMS', 2
          return
        end

        begin
          data = retrieve_data
          data.each_pair do |_key, value|
            @value = value
            @data = value['data']
            check_age || check(:critical) || check(:warning)
          end
          yield "#{name} value okay", 0
        rescue OpenURI::HTTPError
          yield 'Failed to connect to graphite server', 3
        rescue NoMethodError => e
          yield "No data for time period and/or target; #{e.backtrace}", 3
        rescue Errno::ECONNREFUSED
          yield 'Connection refused when connecting to graphite server', 3
        rescue Errno::ECONNRESET
          yield 'Connection reset by peer when connecting to graphite server', 3
        rescue ThresholdReachedWarning => e
          yield e.message, 1
        rescue ThresholdReachedCritical => e
          yield e.message, 2
        rescue AgeThresholdReached => e
          yield e.message, 3
        rescue EOFError
          yield 'End of file error when reading from graphite server', 3
        rescue => e
          yield "An yield error occured: #{e.inspect}; #{e.backtrace}", 3
        end
      end

      # Check the age of the data being processed
      def check_age
        # #YELLOW
        if (Time.now.to_i - @value['end']) > options[:allowed_graphite_age] # rubocop:disable GuardClause
          fail AgeThresholdReached, "Graphite data age is past allowed threshold (#{options[:allowed_graphite_age]} seconds)"
        end
      end

      # grab data from graphite
      def retrieve_data
        # #YELLOW
        unless options[:server].start_with?('https://', 'http://')
          options[:server] = 'http://' + options[:server]
        end

        url = "#{options[:server]}/render?format=json&target=#{formatted_target}&from=#{options[:from]}"

        url_opts = {}

        if options[:no_ssl_verify]
          url_opts[:ssl_verify_mode] = OpenSSL::SSL::VERIFY_NONE
        end

        if options[:username] && (options[:password] || options[:passfile])
          if options[:passfile]
            pass = File.open(options[:passfile]).readline
          elsif options[:password]
            pass = options[:password]
          end

          url_opts[:http_basic_authentication] = [options[:username], pass.chomp]
        end # we don't have both username and password trying without
        handle = open(url, url_opts)

        @raw_data = handle.gets
        if @raw_data == '[]'
          fail 'Empty data received from Graphite - metric probably doesn\'t exists'
        else
          @json_data = JSON.parse(@raw_data)
          output = {}
          @json_data.each do |raw|
            raw['datapoints'].delete_if { |v| v.first.nil? }
            next if raw['datapoints'].empty?
            target = raw['target']
            data = raw['datapoints'].map(&:first)
            start = raw['datapoints'].first.last
            dend = raw['datapoints'].last.last
            step = ((dend - start) / raw['datapoints'].size.to_f).ceil
            output[target] = { 'target' => target, 'data' => data, 'start' => start, 'end' => dend, 'step' => step }
          end
          output
        end
      end
      # type:: :warning or :critical
      # Return alert if required
      def check(type)
        # #YELLOW
        if options[type] # rubocop:disable GuardClause
          if below?(type) || above?(type)
            fail ThresholdReachedWarning, "#{@value['target']} has passed #{type} threshold (#{@data.last})" if type == :warning
            fail ThresholdReachedCritical, "#{@value['target']} has passed #{type} threshold (#{@data.last})" if type == :critical
          end
        end
      end

      # Check if value is below defined threshold
      def below?(type)
        options[:below] && @data.last < options[type]
      end

      # Check is value is above defined threshold
      def above?(type)
        (!options[:below]) && (@data.last > options[type]) && (!decreased?)
      end

      # Check if values have decreased within interval if given
      def decreased?
        if options[:reset_on_decrease]
          slice = @data.slice(@data.size - options[:reset_on_decrease], @data.size)
          val = slice.shift until slice.empty? || val.to_f > slice.first
          !slice.empty?
        else
          false
        end
      end

      # Returns formatted target with hostname replacing any $ characters
      def formatted_target
        if options[:target].include?('$')
          require 'socket'
          @formatted = Socket.gethostbyname(Socket.gethostname).first.gsub('.', options[:hostname_sub] || '_')
          options[:target].gsub('$', @formatted)
        else
          URI.escape options[:target]
        end
      end

      def options
        # we need options to merge in the check[:extension_opts] every time the class is called, as the check may be different
        return @options if @options
        @options = {
          target: '',
          server: 'localhost',
          username: false,
          password: false,
          passfile: false,
          warning: 50,
          critical: 90,
          reset_on_decrease: false,
          name: 'graphite_check',
          allowed_graphite_age: 60,
          hostname_sub: '',
          from: '-10min',
          below: false,
          no_ssl_verify: true
        }

        @required_options = [
          :target,
          :server
        ]

        @options
      end

      private

      def check_options(check)
        options
        @check = check
        if @check[name.to_sym].is_a?(Hash)
          @required_options.each do |required_option|
            unless @check[name.to_sym].key?(required_option)
              puts "ERROR: Missing #{required_option} config param"
              return false
            end
          end
          @options.merge!(@check[name.to_sym])
          true
        else
          false
        end
      end
    end
  end
end
