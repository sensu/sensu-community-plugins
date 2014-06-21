# Resolves a failed check after a specified time.
#
# Designed for stateless downtstream events that can't resolve themselves.
# Events that continue to come in will reset its TTL timer.
#
# Copyright 2014 Jive Software and contributors.
#
# Released under the same terms as Sensu (the MIT license); see LICENSE for details.

require 'net/http'
require 'json'
require 'sensu-plugin/utils'

module Sensu
  module Extension
    class TimeToLive < Handler
      def name
        'ttl'
      end

      def description
        'resets a failed check after a specified time'
      end

      def options
        return @options if @options
        @options = {
          :interval => 60,
        }
        if @settings
          if @settings['ttl'] && @settings['ttl'].is_a?(Hash)
            @options.merge!(@settings[:ttl])
          end
          if @settings['api'] && @settings['api'].is_a?(Hash)
            @options['api'] = @settings['api']
          end
        end
        @options
      end

      def run(event_data)
        retval = process_event_for_ttl(event_data)
        yield(retval, 0)
      end

      def post_init
        @logger.info('Setting up TTL expiration loop')
        if options['api']
          EM::PeriodicTimer.new(options[:interval]) do
            periodic_ttl_expiration
          end
        else
          @logger.info('No API access, deactivating TTL expiration loop')
        end
      end

      def process_event_for_ttl(event_data)
        @logger.info("TTL process event")
        retval = "event has no TTL expiration"
        event = Oj.load(event_data)
        check = event[:check]
        new_expiry = check[:ttl] unless check.nil?
        unless new_expiry.nil?
          client_name = event[:client][:name] unless event[:client].nil?
          check_name = check[:name] unless check.nil?
          @logger.info("Received event with TTL: #{client_name}_#{check_name} expires in #{new_expiry.to_s} seconds")
          now = Time.now.to_i
          expires_at = now + new_expiry
          res = api_post("/stashes/ttl/#{client_name}_#{check_name}", {:ttl => expires_at}.to_json)
          retval = "stashed TTL for event - code " + res.code.to_s
        end
        retval
      end

      def periodic_ttl_expiration
        @logger.info('Starting execution of periodic TTL expirey')
        all_stashes_s = api_get('/stashes')
        all_stashes = JSON.parse(all_stashes_s.body)
        ttl_stashes = all_stashes.select {|x| x['path'] =~ /\Attl\// }
        now = Time.now.to_i
        ttl_stashes.each do |stash|
          check_and_expire_ttl_stash(stash, now)
        end
        @logger.info('Done execution of periodic TTL expirey')
      end

      def check_and_expire_ttl_stash(stash, now)
        expiry = stash['content']['ttl'].to_i unless stash['content'].nil?
        if !expiry.nil? && expiry <= now
          client_name, check_name = names_from_path(stash['path'])
          age = (now - expiry).to_s
          @logger.info("TTL - entry for #{client_name}_#{check_name} expired #{age} seconds ago")
          payload = { :client => client_name, :check => check_name }
          api_post('/resolve', payload.to_json)
          api_delete("/stashes/#{stash['path']}")
        end
      end

      def api_post(path, payload)
        api_request(Net::HTTP::Post, path, payload)
      end

      def api_delete(path)
        api_request(Net::HTTP::Delete, path, nil)
      end

      def api_get(path)
        api_request(Net::HTTP::Get, path, nil)
      end

      def api_request(method, path, payload)
        http = Net::HTTP.new(options['api']['host'], options['api']['port'])
        req = method.new(path)
        if options['api']['user'] && options['api']['password']
          req.basic_auth(options['api']['user'], options['api']['password'])
        end
        unless payload.nil?
          req.body = payload
        end
        http.request(req)
      end

      def logger
        Sensu::Logger.get
      end

      def get_check_data(event_data)
        event = Oj.load(event_data)
        check = event['check']
        new_expiry = check['ttl'] unless check.nil?
        client_name = event['client']['name'] unless event['client'].nil?
        check_name = check['name'] unless check.nil?
        [new_expiry, client_name, check_name]
      end

      def names_from_path(path)
        subpath = path.split('/', 2)[1]
        subpath.split('_', 2)
      end

    end # class TimeToLive
  end # module Extension
end # module Sensu
