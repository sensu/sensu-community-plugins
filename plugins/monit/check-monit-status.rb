#! /usr/bin/env ruby
#
#   <script name>
#
# DESCRIPTION:
#   what is this thing supposed to do, monitor?  How do alerts or
#   alarms work?
#
# OUTPUT:
#   plain text, metric data, etc
#
# PLATFORMS:
#   Linux, Windows, BSD, Solaris, etc
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: <?>
#
# USAGE:
#   example commands
#
# NOTES:
#   Does it behave differently on specific platforms, specific use cases, etc
#
# LICENSE:
#   <your name>  <your email>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

# !/usr/bin/env ruby
#
# Checks Monit Service Statuses
# ===
#
# DESCRIPTION:
#   This plugin checks the status of monit
#   servces via the monit HTTP API.
#
# OUTPUT:
#   plain-text
#
# PLATFORMS:
#   linux
#   bsd
#
# DEPENDENCIES:
#   sensu-plugin ruby gem
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'rexml/document'
require 'net/http'

class CheckMonit < Sensu::Plugin::Check::CLI
  option :host,
         short: '-h host',
         default: '127.0.0.1'

  option :port,
         short: '-p port',
         default: 2812

  option :user,
         short: '-U user'

  option :pass,
         short: '-P pass'

  option :uri,
         short: '-u uri',
         default: '/_status?format=xml'

  option :ignore,
         short: '-i ignore',
         default: ''

  def run
    status_doc = REXML::Document.new(monit_status)
    ignored = config[:ignore].split(',')

    status_doc.elements.each('monit/service') do |svc|
      name = svc.elements['name'].text
      monitored = svc.elements['monitor'].text
      status = svc.elements['status'].text

      next if ignored.include? name

      # #YELLOW
      unless %w( 1 5 ).include? monitored # rubocop:disable IfUnlessModifier
        unknown "#{name} status unkown"
      end

      # #YELLOW
      unless status == '0' # rubocop:disable IfUnlessModifier
        critical "#{name} status failed"
      end
    end

    ok 'All services OK'
  end

  def monit_status
    res = Net::HTTP.start(config[:host], config[:port]) do |http|
      req = Net::HTTP::Get.new(config[:uri])

      # #YELLOW
      unless config[:user].nil? # rubocop:disable IfUnlessModifier
        req.basic_auth config[:user], config[:pass]
      end

      http.request(req)
    end

    unless res.code.to_i == 200
      unknown "Failed to fetch status from #{config[:host]}:#{config[:port]}"
    end

    res.body
  end
end
