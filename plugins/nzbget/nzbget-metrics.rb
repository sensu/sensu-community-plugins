#! /usr/bin/env ruby
#
#   nzbget-metrics
#
# DESCRIPTION:
#   Connects to the NZBGet API to return metrics of NZBGet's current status.
#
# OUTPUT:
#   metric-data
#
# PLATFORMS:
#   Linux, Mac, Windows
#
# USAGE:
#   Default usage:
#     nzbget-metrics.rb -u user -p pass
#
#   Using SSL:
#     nzbget-metrics.rb -u user -p pass --api https://nzbget.dev:6789
#
#   Also supports when NZBGet is behind a proxy:
#     nzbget-metrics.rb -u user -p pass --api http://domain.dev/nzbget
#
# LICENSE:
#   Copyright 2014 Runar Skaare Tveiten <runar@tveiten.io>
#
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'rest-client'
require 'json'

class NzbgetMetric < Sensu::Plugin::Metric::CLI::Graphite
  option :username,
         short: '-u USERNAME',
         long: '--username USERNAME',
         description: 'NZBGet username',
         required: true

  option :password,
         short: '-p PASSWORD',
         long: '--password PASSWORD',
         description: 'NZBGet password',
         required: true

  option :api,
         short: '-a API',
         long: '--api API',
         description: 'NZBGet API location, defaults to http://localhost:6789',
         default: 'http://localhost:6789'

  option :scheme,
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         description: 'Metric naming scheme',
         default: "#{Socket.gethostname}.nzbget"

  def api_request(resource)
    api_uri = "#{config[:api]}/#{config[:username]}:#{config[:password]}"

    begin
      request = RestClient::Resource.new(api_uri + resource)
      JSON.parse(request.get)
    rescue RestClient::ResourceNotFound
      warning "Resource not found: #{resource}"
    rescue Errno::ECONNREFUSED
      warning 'Connection refused'
    rescue Errno::ECONNRESET
      warning 'Connection reset'
    rescue RestClient::RequestFailed
      warning 'Request failed'
    rescue RestClient::RequestTimeout
      warning 'Connection timed out'
    rescue RestClient::Unauthorized
      warning 'Missing or incorrect NZBGet API credentials'
    rescue JSON::ParserError
      warning 'NZBGet API returned invalid JSON'
    rescue OpenSSL::SSL::SSLError => e
      warning "SSL error: #{e}"
    end
  end

  def process_result
    uri = '/jsonrpc/status'
    result = api_request(uri)

    if result.key?('result')
      result['result'].reject! { |k, _| k == 'NewsServers' }
      result['result'].map { |k, v| output "#{config[:scheme]}.#{k}", v }
    else
      critical "Parse error: #{result}"
    end
  end

  def run
    process_result
    ok
  end
end
