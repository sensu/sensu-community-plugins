#! /usr/bin/env ruby
#  encoding: UTF-8
#   check-icecast2-alive.rb
#
# DESCRIPTION:
#   This plugin checks the the status of the icecast2 Server using the
#   XML status endpoint normally available on port 8000
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
#   ./check-icecast2-alive.rb -u admin -p 12345
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
require 'sensu-plugin/check/cli'
require 'crack'
require 'rest-client'

class CheckIcecast2Alive < Sensu::Plugin::Check::CLI
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

  def run
    res = server_alive?

    if res['status'] == 'ok'
      ok res['message']
    elsif res['status'] == 'critical'
      critical res['message']
    else
      unknown res['message']
    end
  end

  def server_alive?
    host     = config[:host]
    port     = config[:port]
    username = config[:username]
    password = config[:password]

    begin
      resource = RestClient::Resource.new "http://#{host}:#{port}/admin/stats", username, password
      status = Crack::XML.parse(resource.get)
      { 'status' => 'ok', 'message' => "#{status['server_id']} server is alive." }
    rescue Errno::ECONNREFUSED => e
      { 'status' => 'critical', 'message' => e.message }
    rescue => e
      { 'status' => 'unknown', 'message' => e.message }
    end
  end
end
