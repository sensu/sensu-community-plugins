#!/usr/bin/env ruby
#
# Sensu Handler for sending / clearing events to the Event Enrichment Platform (EEP)
#
# Copyright 2014 Event Enrichment HQ
#
# Released under the same terms as Sensu (the MIT license); see LICENSE for details.
#
# Dependencies:
#
#   eep_client >= 1.0.0
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
require 'eep_client'

class Eep < Sensu::Handler
  include EepClient::Const

  # some constants
  EEP = 'eep'
  API_TOKEN = 'api_token'
  SENSU_CHECK = 'Sensu Check'
  EVENT = 'event'
  CLEAR = 'clear'

  # sensu event attrs
  S_ACTION = 'action'
  S_CLIENT = 'client'
  S_CHECK = 'check'
  S_SOURCE = 'source'
  S_NAME = 'name'
  S_OUTPUT = 'output'
  S_STATUS = 'status'
  S_EXECUTED = 'executed'
  S_COMMAND = 'command'

  # sensu event attr vals
  S_STATUS_OK = 0
  S_STATUS_WARNING = 1
  S_STATUS_CRITICAL = 2

  S_ACTION_CREATE = 'create'
  S_ACTION_RESOLVE = 'resolve'

  # severity mapping
  SEVERITY_MAP = {
    S_STATUS_OK => SEV_INFO,
    S_STATUS_WARNING => SEV_WARNING,
    S_STATUS_CRITICAL => SEV_CRITICAL
  }

  def handle
    # get EEP client config
    config = settings[EEP]
    bail 'CONFIG ERROR: eep settings not found in sensu configuration files' unless config

    # create EEP client
    api_token = config.delete(API_TOKEN)
    bail 'CONFIG ERROR: api_token not found in eep settings in sensu configuration files' unless api_token

    # remap config to options hash with sym keys
    options = {}
    config.each { |k, v| options[k.to_sym] = v }

    ec = EepClient.new(api_token, options)

    # read Sensu event
    action = @event[S_ACTION]
    client_name = @event[S_CLIENT][S_NAME]
    check = @event[S_CHECK]
    check_name = check[S_NAME]
    source = check[S_SOURCE] || client_name

    local_instance_id = gen_local_instance_id(client_name, check_name)

    if action == S_ACTION_CREATE
      output = check[S_OUTPUT].strip
      status = check[S_STATUS]
      executed = check[S_EXECUTED]
      send_type = EVENT

      # map to event
      data = {
        local_instance_id: local_instance_id,
        source_location: source,
        creation_time: executed,
        msg: output,
        event_class: SENSU_CHECK,
        severity: SEVERITY_MAP[status],
        reporter_location: client_name,
        reporter_component: check_name
      }
    else
      send_type = CLEAR
      # map to clear
      data = {
        local_instance_id: local_instance_id,
        source_location: source
      }
    end

    # send to EEP
    begin
      timeout(10) do
        if send_type == EVENT
          res = ec.send_event(data)
        else
          res = ec.send_clear(data)
        end

        if res.is_a? EepClient::OkResponse
          puts "#{EEP} handler sent #{send_type} to EEP for local_instance_id #{local_instance_id} - #{res}"
        else
          puts "ERROR - #{EEP} handler failed to send #{send_type} to EEP for local_instance_id #{local_instance_id} - #{res}"
        end
      end
    rescue Timeout::Error
      puts "ERROR - #{EEP} handler timed out sending #{send_type} for local_instance_id #{local_instance_id}"
    rescue StandardError => e
      puts "ERROR - #{EEP} handler failed to send #{send_type} to EEP for local_instance_id #{local_instance_id} - #{e.message}"
    end
  end

  private

  def gen_local_instance_id(client_name, check)
    "sensu:#{client_name}/#{check}"
  end
end
