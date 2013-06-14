#!/usr/bin/env ruby
#
# Check Pingdom Credits
# ===
#
# Released under the same terms as Pingdom (the MIT license); see
# LICENSE for details.

require "rubygems"
require "sensu-plugin/check/cli"
require "rest-client"
require "json"

class CheckPingdomCredits < Sensu::Plugin::Check::CLI

  API_ROOT = "https://api.pingdom.com"
  API_VERSION = "2.0"

  CREDIT_KEYS = [
    :availablesms,
    :availablechecks,
  ].freeze

  option :api_key,
    :short => "-k KEY",
    :long => "--pingdom-key KEY",
    :description => "Pingdom API Key"

  option :user,
    :short => "-u USER",
    :long => "--user USER",
    :description => "Pingdom User"

  option :password,
    :short => "-p PASSWORD",
    :long => "--password PASSWORD",
    :description => "Pingdom Password"

  CREDIT_KEYS.each do |key|
    option :"warn_#{key}",
      :long => "--warn-#{key} COUNT",
      :description => "Minimum #{key} before warning",
      :proc => proc {|a| a.to_i }

    option :"crit_#{key}",
      :long => "--crit-#{key} COUNT",
      :description => "Minimum #{key} before critical",
      :proc => proc {|a| a.to_i }
  end

  def api_request(resource)
    begin
      request = RestClient::Resource.new(
       "#{API_ROOT}/api/#{API_VERSION}/#{resource}", {
        :user => config[:user],
        :password => config[:password],
        :headers => {
          "App-Key" => config[:api_key]
        },
      })
      JSON.parse(request.get, :symbolize_names => true)
    rescue Errno::ECONNREFUSED
      warning "Connection refused"
    rescue RestClient::RequestFailed
      warning "Request failed"
    rescue RestClient::RequestTimeout
      warning "Connection timed out"
    rescue RestClient::Unauthorized
      warning "Missing or incorrect Pingdom API credentials"
    rescue JSON::ParserError
      warning "Pingdom API returned invalid JSON"
    end
  end

  def get_credits
    uri = "/credits"
    credits = api_request(uri)
    credits[:credits]
  end

  def compare_thresholds(credits)
    message = credits_message(credits)
    CREDIT_KEYS.each do |key|
      if config[:"crit_#{key}"] &&
          credits[key] < config[:"crit_#{key}"]
        critical message
      elsif config[:"warn_#{key}"] &&
          credits[key] < config[:"warn_#{key}"]
        warning message
      else
        ok message
      end
    end
  end

  def run
    credits = get_credits
    compare_thresholds(credits)
  end

  private

    def credits_message(credits)
      CREDIT_KEYS.inject([]) do |ary, credit|
        ary << "#{credit}=#{credits[credit]}"
      end.join(", ")
    end

end
