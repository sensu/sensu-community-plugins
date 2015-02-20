#! /usr/bin/env ruby
#
#   metrics-json
#
# DESCRIPTION:
#   Takes either a URL or a combination of host/path/query/port/ssl, and retrive
#   the metric specified in the key field.
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
#   to access sub json keys user '/' as separator
#   Ex:
#   { "key": {"subkey":"value"}} value can be retrived with --key key/subkey
#   #YELLOW
#
# NOTES:
#   Based on Check HTTP Json by Matt Revell
#
# LICENSE:
#   Copyright 2015 Andrea Minetti (wavein.ch) <andrea@wavein.ch>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'json'
require 'net/http'
require 'net/https'

class JsonMetric < Sensu::Plugin::Metric::CLI::Graphite
  option :url, short: '-u URL'
  option :host, short: '-h HOST'
  option :path, short: '-p PATH'
  option :query, short: '-q QUERY'
  option :port, short: '-P PORT', proc: proc(&:to_i)
  option :header, short: '-H HEADER', long: '--header HEADER'
  option :ssl, short: '-ssl', boolean: true, default: false
  option :insecure, short: '-k', boolean: true, default: false
  option :user, short: '-U', long: '--username USER'
  option :password, short: '-a', long: '--password PASS'
  option :cert, short: '-c FILE'
  option :cacert, short: '-C FILE'
  option :timeout, short: '-t SECS', proc: proc(&:to_i), default: 15
  option :key, short: '-K KEY', long: '--key KEY'
  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         required: true
  
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
          json = JSON.parse(res.body)

	  config[:key].split("/").each do |path|
            json = json[path]
	  end

	  output "#{config[:scheme]}", json.to_s 
	  ok 
      else
        critical 'Response contains invalid JSON'
      end
    else
      critical res.code
    end
  end
end
