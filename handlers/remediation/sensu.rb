#!/usr/bin/env ruby
#
##################
# Sensu Remediator
##################
#
# This plugin reads configuration from a check definition
# and triggers appropriate remediation actions (defined as
# other checks) via the Sensu API, when the occurrences and
# severities reach certain values.
#
# The severities should be a list of integers.
#
# The occurrences should be an array of Integers, or strings,
# where the strings are dash seperated integers or plus
# suffixed integers.
#
# By default, the remediation checks will be triggered on the
# the client where the check is failing.  An array of
# subscriptions may be specified via a 'trigger_on' property
# of the 'remediation' dictionary.
#
# Example:
#
# {
#   "checks": {
#     "check_something": {
#       "command": "ps aux | grep cron",
#       "interval": 60,
#       "subscribers": ["application_server"],
#       "handler": ["debug", "irc", "remediator"],
#       "remediation": {
#         "light_remediation": {
#           "occurrences": [1, 2],
#           "severities": [1]
#         },
#         "medium_remediation": {
#           "occurrences": ["3-10"],
#           "severities": [1]
#         },
#         "heavy_remediation": {
#           "occurrences": ["1+"],
#           "severities": [2]
#         }
#       }
#     },
#     "light_remediation": {
#       "command": "/bin/something",
#       "subscribers": [],
#       "handler": ["debug", "irc"],
#       "publish": false,
#     },
#     "medium_remediation": {
#       "command": "/bin/something_else",
#       "subscribers": [],
#       "handler": ["debug", "irc"],
#       "publish": false,
#     },
#     "heavy_remediation": {
#       "command": "sudo reboot",
#       "subscribers": [],
#       "handler": ["debug", "irc"],
#       "publish": false,
#     }
#   }
# }
# ===
#
# Copyright 2012 Nick Stielau <nick.stielau@gamil.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'

class Remediator < Sensu::Handler

  # Override filter_repeated from Sensu::Handler.
  # Remediations are not alerts.
  def filter_repeated; end

  def handle
    client = @event['client']['name']
    remediations = @event['check']['remediation']
    occurrences = @event['occurrences']
    severity = @event['check']['status'].to_i
    puts "REMEDIATION: Evaluating remediation: #{client} #{remediations.inspect} #=#{occurrences} sev=#{severity}"

    remediation_checks = parse_remediations(remediations, occurrences, severity)

    subscribers = remediations['trigger_on'] ? [remediations['trigger_on']].flatten : [client]
    remediation_checks.each do |remediation_check|
      puts "REMEDIATION: Triggering remediation check '#{remediation_check}' for #{[client].inspect}"
      response = trigger_remediation(remediation_check, subscribers)
      puts "REMEDIATION: Recieved API Response (#{response.code}): #{response.body}, exiting."
    end
  end

  # Examine the defined remediations and return an array of
  # checks that should be triggered given the current occurrence
  # count and severity.
  def parse_remediations(remediations, occurrences, severity)
    remediations_to_trigger = []

    remediations.each do |check, conditions|
      # Check for remediations matching the current occurrence count
      (conditions["occurrences"] || []).each do |value|
        if value.is_a?(Integer)
          next unless occurrences == value
        elsif value.to_s.match(/^\d+$/)
          parsed_value = $~.to_a.first.to_i
          next unless occurrences == parsed_value
        elsif value.to_s.match(/^(\d+)-(\d+)$/)
          range = Range.new($~.to_a[1].to_i, $~.to_a[2].to_i).to_a
          next unless range.include?(occurrences)
        elsif value.to_s.match(/^(\d+)\+$/)
          puts "REMEDIATION: Matchdata: #{$~.inspect}"
          range = Range.new($~.to_a[1].to_i, 9999).to_a
          next unless range.include?(occurrences)
        end
      end

      # Check remediations matching the current severity
      next unless (conditions["severities"] || []).include?(severity)

      remediations_to_trigger << check
    end
    remediations_to_trigger
  end

  # Issue a check via the API
  def trigger_remediation(check, subscribers)
    api_request(:POST, '/checks/request') do |req|
      req.body = JSON.dump({"check" => check, "subscribers" => subscribers})
    end
  end

end