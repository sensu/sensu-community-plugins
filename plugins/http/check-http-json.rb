#! /usr/bin/env ruby
#
#   check-http-json
#
# DESCRIPTION:
#   Takes either a URL or a combination of host/path/query/port/ssl, and checks
#   for valid JSON output in the response. Can also optionally validate simple
#   string key/value pairs.
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: json
#   gem: net/http
#
# USAGE:
#   #YELLOW
#
# NOTES:
#   Based on Check HTTP by Sonian Inc.
#
# LICENSE:
#   Copyright 2013 Matt Revell <nightowlmatt@gmail.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'json'
require 'net/http'
require 'net/https'

class CheckJson < Sensu::Plugin::Check::CLI
  option :url, short: '-u URL'
  option :host, short: '-h HOST'
  option :path, short: '-p PATH'
  option :query, short: '-q QUERY'
  option :port, short: '-P PORT', proc: proc(&:to_i)
  option :header, short: '-H HEADER', long: '--header HEADER'
  option :ssl, short: '-s', boolean: true, default: false
  option :insecure, short: '-k', boolean: true, default: false
  option :user, short: '-U', long: '--username USER'
  option :password, short: '-a', long: '--password PASS'
  option :cert, short: '-c FILE'
  option :cacert, short: '-C FILE'
  option :timeout, short: '-t SECS', proc: proc(&:to_i), default: 15
  option :key, short: '-K KEY', long: '--key KEY'
  option :value, short: '-v VALUE', long: '--value VALUE'

  def run
    if config[:url]
      uri = URI.parse(config[:url])
      config[:host] = uri.host
      config[:path] = uri.path
      config[:query] = uri.query
      config[:port] = uri.port
      config[:ssl] = uri.scheme == 'https'
    else
      # #YELLOW
      unless config[:host] && config[:path] # rubocop:disable IfUnlessModifier
        unknown 'No URL specified'
      end
      config[:port] ||= config[:ssl] ? 443 : 80
    end

    begin
      timeout(config[:timeout]) do
        acquire_resource
      end
    rescue Timeout::Error
      critical 'Connection timed out'
    rescue => e
      critical "Connection error: #{e.message}"
    end
  end

  def json_valid?(str)
    JSON.parse(str)
    return true
  rescue JSON::ParserError
    return false
  end

  def acquire_resource
    http = Net::HTTP.new(config[:host], config[:port])

    if config[:ssl]
      http.use_ssl = true
      if config[:cert]
        cert_data = File.read(config[:cert])
        http.cert = OpenSSL::X509::Certificate.new(cert_data)
        http.key = OpenSSL::PKey::RSA.new(cert_data, nil)
      end
      http.ca_file = config[:cacert] if config[:cacert]
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE if config[:insecure]
    end

    req = Net::HTTP::Get.new([config[:path], config[:query]].compact.join('?'))
    if !config[:user].nil? && !config[:password].nil?
      req.basic_auth config[:user], config[:password]
    end
    if config[:header]
      config[:header].split(',').each do |header|
        h, v = header.split(':', 2)
        req[h] = v.strip
      end
    end
    res = http.request(req)

    case res.code
    when /^2/
      if json_valid?(res.body)
        if !config[:key].nil? && !config[:value].nil?
          json = JSON.parse(res.body)
          # #YELLOW
          if json[config[:key]].to_s == config[:value].to_s # rubocop:disable BlockNesting
            ok 'Valid JSON and key present and correct'
          else
            critical 'JSON key check failed'
          end
        else
          ok 'Valid JSON returned'
        end
      else
        critical 'Response contains invalid JSON'
      end
    else
      critical res.code
    end
  end
end
