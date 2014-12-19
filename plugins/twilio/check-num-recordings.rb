#! /usr/bin/env ruby
#
#   check-num-recordings
#
# DESCRIPTION:
#   Checks the number of recordings in Twilio
#
# OUTPUT:
#   plain text, metric data, etc
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: uri
#   gem: nori
#
# USAGE:
#   #YELLOW
#
# NOTES:
#
# LICENSE:
#   Copyright (c) 2013, Justin Lambert <jlambert@letsevenup.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'net/http'
require 'net/https'
require 'uri'
require 'nori'

class TwilioRecordings < Sensu::Plugin::Check::CLI
  option :account_sid,
         short: '-s ACCOUNT_SID',
         long: '--account-sid ACCOUNT_SID',
         description: 'SID for the account being checked',
         required: true

  option :account_token,
         short: '-t ACCOUNT_TOKEN',
         long: '--account-token ACCOUNT_TOKEN',
         description: 'Secret token for the account being checked',
         required: true

  option :warning,
         short: '-w WARN_NUM',
         long: '--warnnum WARN_NUM',
         description: 'Number of recordings considered to be a warning',
         required: true

  option :critical,
         short: '-c CRIT_NUM',
         long: '--critnum CRIT_NUM',
         description: 'Number of recordings considered to be critical',
         required: true

  option :name,
         short: '-n NAME',
         long: '--name NAME',
         description: 'Human readable description for the account'

  option :root_ca,
         long: '--root-ca ROOT_CA_FILE',
         description: 'Root CA file that should be used for SSL verification',
         default: '/etc/pki/tls/certs/ca-bundle.crt'

  def run
    name = config[:name] || config[:account_sid]

    # Set up HTTP request
    uri = URI.parse("https://api.twilio.com/2010-04-01/Accounts/#{config[:account_sid]}/Recordings")
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true

    # Verify SSL cert if possible
    if File.exist?(config[:root_ca]) && http.use_ssl?
      http.ca_file = config[:root_ca]
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      http.verify_depth = 5
    else
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end

    request = Net::HTTP::Get.new(uri.request_uri)
    request.basic_auth(config[:account_sid], config[:account_token])
    response = http.request(request)

    # Handle unknown response
    unknown "Received #{response.code} response code from Twilio checking account #{name}" if response.code != '200'

    # Parse Twilio XML
    messages = Nori.new(advanced_typecasting: false, advanced_typecasting: false).parse(response.body)
    total = messages['TwilioResponse']['Recordings']['@total'].to_i

    if total >= config[:critical].to_i
      critical "#{total} recordings pending in Twilio account #{name}"
    elsif total >= config[:warning].to_i
      warning "#{total} recordings pending in Twilio account #{name}"
    else
      ok "#{total} recordings pending in Twilio account #{name}"
    end
  end
end
