#! /usr/bin/env ruby
#  encoding: UTF-8
#   icecast2-metrics.rb
#
# DESCRIPTION:
#   This plugin exports the internal stats of an icecast2 server in graphite
#   format.
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: crack
#   gem: rest-client
#
# USAGE:
#   ./icecast2-metrics.rb -u admin -p 12345
#
# NOTES:
#   This plugin requires a username and password with permission to access
#   the /admin/stats API call in the icecast2 server.
#
# LICENSE:
#   Adam Ashley <aashley@adamashley.name>
#   Swift Networks
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'crack'
require 'rest-client'

class Icecast2Metrics < Sensu::Plugin::Metric::CLI::Graphite
  option :host,
         description: 'icecast2 host',
         short: '-h',
         long: '--host HOST',
         default: 'localhost'

  option :username,
         description: 'icecast2 username',
         short: '-u',
         long: '--username USERNAME',
         required: true

  option :password,
         description: 'icecast2 password',
         short: '-p',
         long: '--password PASSWORD',
         required: true

  option :port,
         description: 'RabbitMQ API port',
         short: '-P',
         long: '--port PORT',
         default: '8000'

  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         default: "#{Socket.gethostname}.icecast2"

  def run
    host     = config[:host]
    port     = config[:port]
    username = config[:username]
    password = config[:password]
    scheme   = config[:scheme]

    begin
      resource = RestClient::Resource.new "http://#{host}:#{port}/admin/stats", username, password
      status = Crack::XML.parse(resource.get)

      %w{
        clients
        listeners
        sources
        stats
      }.each do |stat|
        output "#{scheme}.active.#{stat}", status['icestats'][stat]
      end

      %w{
        client_connections
        connections
        file_connections
        listener_connections
        source_client_connections
        source_relay_connections
        source_total_connections
        stats_connections
      }.each do |stat|
        output "#{scheme}.connections.#{stat}", status['icestats'][stat]
      end
      status['icestats']['source'].each do |source|
        source_name = source['mount'].gsub(/^\//, '')
        %w{
          bitrate
          listeners
          slow_listeners
          total_bytes_read
          total_bytes_sent
        }.each do |stat|
          if source[stat]
            output "#{scheme}.sources.#{source_name}.#{stat}", source[stat]
          else
            # Some of the stats are not available until someone connects for
            # the first time. Return 0.
            output "#{scheme}.sources.#{source_name}.#{stat}", 0
          end
        end
      end
      ok
    rescue => e
      puts "Error: exception: #{e}"
      critical
    end
  end
end
