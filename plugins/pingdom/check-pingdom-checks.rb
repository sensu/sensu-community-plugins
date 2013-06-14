#!/usr/bin/env ruby
#
# Check Pingdom Checks
# ===
#
# Released under the same terms as Pingdom (the MIT license); see
# LICENSE for details.

require "rubygems"
require "sensu-plugin/check/cli"
require "rest-client"
require "json"

class CheckPingdomChecks < Sensu::Plugin::Check::CLI

  API_ROOT = "https://api.pingdom.com"
  API_VERSION = "2.0"

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

  option :warning,
    :short => "-w COUNT",
    :long => "--warning COUNT",
    :description => "COUNT non-up before warning",
    :proc => proc {|a| a.to_i }

  option :critical,
    :short => "-c COUNT",
    :long => "--critical COUNT",
    :description => "COUNT non-up before critical",
    :proc => proc {|a| a.to_i }

  option :verbose,
    :short => "-v",
    :long => "--verbose",
    :boolean => true

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

  def get_checks
    uri = "/checks"
    checks = api_request(uri)
    checks[:checks]
  end

  def compare_thresholds(checks)
    down = down_checks(checks)
    message = checks_message(checks)
    if config[:critical] && down.count >= config[:critical]
      critical message
    elsif config[:warning] && down.count >= config[:warning]
      warning message
    else
      ok message
    end
  end

  def run
    checks = get_checks
    compare_thresholds(checks)
  end

  private

    def down_checks(checks)
      checks.select do |check|
        check[:status].downcase.to_sym == :down
      end
    end

    def checks_message(checks)
      checks.inject(Hash.new(0)) do |h, check|
        h[check[:status].upcase] += 1
        h
      end.map do |key, count|
        count > 1 ? "#{count} are #{key}" : "#{count} is #{key}"
      end.join(", ") + down_listings(checks)
    end

    def down_listings(checks)
      listing = ""
      if config[:verbose]
        listing = down_checks(checks).map do |check|
          sprintf("%s is %s", check[:hostname], check[:status].upcase)
        end.join("\n")
      end
      if listing.empty?
        listing
      else
        "\n#{listing}"
      end
    end

end
