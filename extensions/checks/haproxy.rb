# Haproxy check
#
# Checks haproxy backends and reports on the status
#
# REQUIRES SENSU 0.17.1 or HIGHER
#
# Usage
# {
#   "checks": {
#     "check_haproxy": {
#       "extension": "haproxy",
#       "subscribers": [],
#       "handlers": [
#         "default"
#       ],
#       "interval": 20,
#       "haproxy": {
#         "stats_source": "localhost",
#         "port": "22002", #required
#         "service": "backend1", # optional
#         "crit_percent": 51, #optional
#         "warn_percent": 70, #optional
#         "all_services": "false"
#       }
#     }
#   }
# }
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'net/http'
require 'socket'
require 'csv'
require 'uri'

module Sensu
  module Extension
    class Haproxy < Check
      def name
        'haproxy'
      end

      def description
        'checks haproxy backends'
      end

      def definition
        {
          type:  'check',
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
          yield 'MISSING REQUIRED CONFIG PARAMS', 2
          return false
        end

        if options[:service] || options[:all_services]
          begin
            services = acquire_services
          rescue => e
            yield e.message, 3
            return
          end
        else
          yield 'No service specified', 3
          return
        end

        if services.empty?
          if options[:missing_ok]
            yield 'No services found, but it\'s ok', 0
          else
            yield 'No services found', 1
          end
        else
          percent_up = 100 * services.select { |svc| svc[:status] == 'UP' || svc[:status] == 'OPEN' }.size / services.size
          failed_names = services.reject { |svc| svc[:status] == 'UP' || svc[:status] == 'OPEN' }.map { |svc| svc[:svname] }
          critical_sessions = services.select { |svc| svc[:slim].to_i > 0 && (100 * svc[:scur].to_f / svc[:slim].to_f) > options[:session_crit_percent] }
          warning_sessions = services.select { |svc| svc[:slim].to_i > 0 && (100 * svc[:scur].to_f / svc[:slim].to_f) > options[:session_warn_percent] }

          status = "#{100 - percent_up}% of #{services.size} of #{options[:service]} are DOWN; "\
            + (failed_names.empty? ? '' : " NODES: #{failed_names.join(', ')}")
          if percent_up < options[:crit_percent]
            yield status, 2
          elsif !critical_sessions.empty?
            yield status + '; Active sessions critical: ' + critical_sessions.map { |s| "#{s[:scur]} #{s[:svname]}" }.join(', '), 2
          elsif percent_up < options[:warn_percent]
            yield status, 1
          elsif !warning_sessions.empty?
            yield status + '; Active sessions warning: ' + warning_sessions.map { |s| "#{s[:scur]} #{s[:svname]}" }.join(', '), 1
          else
            yield status, 0
          end
        end
      end

      def socket_request
        srv = UNIXSocket.open(options[:stats_source])
        srv.write("show stat\n")
        out = srv.read
        srv.close
        out
      end

      def http_request
        res = Net::HTTP.start(options[:stats_source], options[:port]) do |http|
          req = Net::HTTP::Get.new("/#{options[:path]};csv;norefresh")
          unless options[:username].nil?
            req.basic_auth options[:username], options[:password]
          end
          http.request(req)
        end
        unless res.code.to_i == 200
          fail "Failed to fetch from #{options[:stats_source]}:#{options[:port]}/#{options[:path]}: #{res.code}"
        end
        res.body
      end

      def acquire_services
        uri = URI.parse(options[:stats_source])
        if uri.is_a?(URI::Generic) && File.socket?(uri.path)
          out = socket_request
        else
          out = http_request
        end

        parsed = CSV.parse(out, skip_blanks: true)
        keys = parsed.shift.reject(&:nil?).map { |k| k.match(/(\w+)/)[0].to_sym }
        haproxy_stats = parsed.map { |line| Hash[keys.zip(line)] }
        if options[:all_services]
          haproxy_stats
        else
          regexp = options[:exact_match] ? Regexp.new("^#{options[:service]}$") : Regexp.new("#{options[:service]}")
          haproxy_stats.select do |svc|
            svc[:pxname] =~ regexp
            # #YELLOW
          end.reject do |svc| # rubocop: disable MultilineBlockChain
            %w(FRONTEND BACKEND).include?(svc[:svname])
          end
        end
      end

      def options
        # we need options to merge in the check[:extension_opts] every time the class is called, as the check may be different
        return @options if @options

        @options = {
          stats_source: '',
          port: 80,
          path: '/',
          username: '',
          password: '',
          warn_percent: 50,
          crit_percent: 25,
          session_warn_percent: 75,
          session_crit_percent: 90,
          all_services: true,
          missing_ok: true,
          service: false,
          exact_match: false
        }

        @required_options = [
          :stats_source,
          :port
        ]

        @options
      end

      private

      def check_options(check)
        options
        @check = check
        if @check[:haproxy].is_a?(Hash)
          @required_options.each do |required_option|
            unless @check[:haproxy].key?(required_option)
              puts "ERROR: Missing #{required_option} config param", 2
              return false
            end
          end
          @options.merge!(@check[:haproxy])
          true
        else
          false
        end
      end
    end
  end
end
