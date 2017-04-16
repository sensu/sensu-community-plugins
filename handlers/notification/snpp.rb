#!/usr/bin/env ruby

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'

class SnppHandler < Sensu::Handler
	def event_name
		@event['client']['name'] + '/' + @event['check']['name']
	end

	def action_to_string
		@event['action'].eql?('resolve') ? 'RESOLVED' : 'ALERT'
	end

	def status_to_string
		case @event['check']['status']
		when 0
			'OK'
		when 1
			'WARNING'
		when 2
			'CRITICAL'
		else
			'UNKNOWN'
		end
	end

	def handle
		snpp_server = settings['snpp']['server']
		snpp_contacts = settings['snpp']['contacts']
		body = <<-BODY.gsub(/^\s+/, '')
		#{@event['check']['output']}
			Host: #{@event['client']['name']}
			Timestamp: #{Time.at(@event['check']['issued'])}
			Address: #{@event['client']['address']}
			Status: #{status_to_string}
			Occurrences: #{@event['occurrences']}
			BODY

		for contact in snpp_contacts
			system("/usr/bin/snpp -s #{snpp_server} -m \"#{body}\" -n #{contact}")
		end
	end
end
