#!/usr/bin/env ruby
#
# Sensu Handler: ponymailer
#
# This handler formats alerts as mails and sends them off to a pre-defined recipient.
#
# Copyright 2012 Panagiotis Papadomitsos <pj@ezgr.net>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
require 'timeout'
require 'pony'
require 'date'

class PonyMailer < Sensu::Handler

    STATUSES = {
        0 => 'OK',
        1 => 'WARNING',
        2 => 'CRITICAL'
    }

    def short_name
        @event['client']['name'] + '/' + @event['check']['name']
    end

    def action_to_string
     @event['action'].eql?('resolve') ? "RESOLVED" : "ALERT"
    end

    def handle

        mailOptions = {
            :subject => "Sensu Monitoring Alert: #{action_to_string} :: #{short_name}",
            :from => "#{settings['ponymailer']['fromname']} <#{settings['ponymailer']['from']}>",
            :via => :smtp,
            :arguments => '',
            :via_options => {
                :address => settings['ponymailer']['hostname'],
                :port => settings['ponymailer']['port'],
                :enable_starttls_auto => settings['ponymailer']['tls'],
            },
            :charset => 'utf-8',
            :sender => settings['ponymailer']['from'],
        }
        mailOptions.merge!({
            :via_options => {
                :address => settings['ponymailer']['hostname'],
                :port => settings['ponymailer']['port'],
                :enable_starttls_auto => settings['ponymailer']['tls'],
                :user_name => settings['ponymailer']['username'],
                :password => settings['ponymailer']['password'],
                :authentication => :plain
            }
        }) if settings['ponymailer']['authenticate']

        mailOptions[:body] = %Q{Sensu has detected a failed check. Event analysis follows:

Event Timestamp:    #{Time.at(@event['check']['issued'].to_i)}

Check That Failed:  #{@event['check']['name']}
Check Command:      #{@event['check']['command']}
Check Flapping:     #{@event['check']['flapping'].to_s}
Check Occurrences:  #{@event['occurrences']}
Check History:      #{@event['check']['history'].map{ |h| STATUSES[h.to_i] }.join(' => ')}

Node Name:          #{@event['client']['name']}
Node IP Address:    #{@event['client']['address']}
Node LPOL:          #{Time.at(@event['client']['timestamp'].to_i)}
Node Subscriptions: #{@event['client']['subscriptions'].join(', ')}

====================
=== Check Output ===
====================

#{@event['check']['output']}

}
        Pony.options = mailOptions

        unless settings['ponymailer']['recipients'].empty?
            settings['ponymailer']['recipients'].each do |to|
                begin
                    Timeout.timeout 10 do
                        Pony.mail({ :to => to })
                        puts 'mail -- sent alert for ' + short_name + ' to ' + to
                    end
                rescue Timeout::Error
                    puts 'mail -- timed out while attempting to ' + @event['action'] + ' an incident -- ' + short_name
                end
            end
        end
    end
end
