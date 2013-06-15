#!/usr/bin/env ruby
#
# Check Pingdom credits
# ===
#
# Checks that there are enough SMS credits and website checks left in a
# Pingdom account.
#
# Usage
#   Authentication
#     Pingdom's API requires 3 parameters for authentication:
#       --user: the user's email
#       --password: the user's password
#       --application-key: create one at https://my.pingdom.com/account/appkeys
#
#   Alerts
#     SMS left
#       --crit-available-sms
#       --warn-available-sms
#     Website checks left
#       --crit-available-checks
#       --warn-available-checks
#
# Dependencies
#
# gem 'rest-client'
# gem 'json'
#
# Copyright 2013 Rock Solid Ops Inc. <hello@rocksolidops.com>
# Created by Mathieu Martin, 2013
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'rest-client'
require 'json'

class CheckPingdomCredits < Sensu::Plugin::Check::CLI
  option :user,
    :short => '-u EMAIL',
    :required => true
  option :password,
    :short => '-p PASSWORD',
    :required => true
  option :application_key,
    :short => '-k APP_KEY',
    :long => '--application-key APP_KEY',
    :required => true

  option :warn_sms,
    :long => '--warn-available-sms COUNT',
    :default => 10,
    :proc => proc {|a| a.to_i }
  option :crit_sms,
    :long => '--crit-available-sms COUNT',
    :default => 5,
    :proc => proc {|a| a.to_i }

  option :warn_checks,
    :long => '--warn-available-checks COUNT',
    :default => 3,
    :proc => proc {|a| a.to_i }
  option :crit_checks,
    :long => '--crit-available-checks COUNT',
    :default => 1,
    :proc => proc {|a| a.to_i }

  option :timeout,
    :short => '-t SECS',
    :default => 10

  def run
    check_sms!
    check_checks! # LOL @ name clashes
    ok 'Pingdom credits ok' if sms_ok && checks_ok
  end

  attr_reader :sms_ok
  attr_reader :checks_ok

  def check_sms!
    message = "Only #{available_sms} Pingdom SMS left (threshold %{threshold})"
    if config[:crit_sms] >= available_sms
      critical(message % { :threshold => config[:crit_sms] })
    elsif config[:warn_sms] >= available_sms
      warning(message % { :threshold => config[:warn_sms] })
    else
      @sms_ok = true
    end
  end

  def check_checks!
    message = "Only #{available_checks} Pingdom checks left (threshold %{threshold})"
    if config[:crit_checks] >= available_checks
      critical(message % { :threshold => config[:crit_checks] })
    elsif config[:warn_checks] >= available_checks
      warning(message % { :threshold => config[:warn_checks] })
    else
      @checks_ok = true
    end
  end

  def available_sms
    credits[:availablesms]
  end

  def available_checks
    credits[:availablechecks]
  end

  def credits
    # Cache the API call
    @credits ||= api_call[:credits]
  end

  def api_call
    resource = RestClient::Resource.new(
      'https://api.pingdom.com/api/2.0/credits',
      :user     => config[:user],
      :password => config[:password],
      :headers  => { 'App-Key' => config[:application_key] },
      :timeout  => config[:timeout]
    )
    JSON.parse(resource.get, :symbolize_names => true)

  rescue RestClient::RequestTimeout
    warning "Connection timeout"
  rescue SocketError
    warning "Network unavailable"
  rescue Errno::ECONNREFUSED
    warning "Connection refused"
  rescue RestClient::RequestFailed
    warning "Request failed"
  rescue RestClient::RequestTimeout
    warning "Connection timed out"
  rescue RestClient::Unauthorized
    warning "Missing or incorrect API credentials"
  rescue JSON::ParserError
    warning "API returned invalid JSON"
  end

end
