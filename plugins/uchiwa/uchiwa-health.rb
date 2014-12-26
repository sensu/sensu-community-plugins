#! /usr/bin/env ruby
#
#   uchiwa-health
#
# DESCRIPTION:
#   Check health of Uchiwa and configured Sensu endpoints
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
#   gem: uri
#
# USAGE:
#  #YELLOW
#
# NOTES:
#
# LICENSE:
#   Copyright 2014 Grant Heffernan <grant@mapzen.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'net/http'
require 'net/https'
require 'json'
require 'uri'

class UchiwaHealthCheck < Sensu::Plugin::Check::CLI
  option :host,
         short: '-h HOST',
         long: '--host HOST',
         description: 'Your uchiwa endpoint',
         required: true,
         default: 'localhost'

  option :port,
         short: '-P PORT',
         long: '--port PORT',
         description: 'Your uchiwa port',
         required: true,
         default: 3000

  option :username,
         short: '-u USERNAME',
         long: '--username USERNAME',
         description: 'Your uchiwa username',
         required: false

  option :password,
         short: '-p PASSWORD',
         long: '--password PASSWORD',
         description: 'Your uchiwa password',
         required: false

  def json_valid?(str)
    JSON.parse(str)
    return true
  rescue JSON::ParserError
    return false
  end

  def run
    endpoint = "http://#{config[:host]}:#{config[:port]}"
    url      = URI.parse(endpoint)

    begin
      res = Net::HTTP.start(url.host, url.port) do |http|
        req = Net::HTTP::Get.new('/health')
        req.basic_auth config[:username], config[:password] if config[:username] && config[:password]
        http.request(req)
      end
    rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError, Net::HTTPBadResponse,
           Net::HTTPHeaderSyntaxError, Net::ProtocolError, Errno::ECONNREFUSED => e
      critical e
    end

    if json_valid?(res.body)
      json = JSON.parse(res.body)
      json.keys.each do |k|
        if k.to_s == 'uchiwa'
          critical 'Uchiwa status != ok' if json['uchiwa'].to_s != 'ok'
        elsif k.to_s == 'sensu'
          json['sensu'].each do |key, val|
            # #YELLOW
            if val['output'].to_s != 'ok' # rubocop:disable IfUnlessModifier
              critical "Sensu status != ok for Sensu API \"#{key}\". Error is \"#{val['output']}\""
            end
          end
        else
          critical "Unrecognized keys found in Uchiwa response: #{k}"
        end
      end
    else
      critical 'Response contains invalid JSON'
    end

    ok
  end
end
