#!/usr/bin/env ruby
#
# Delete stashes when their 'expires' timestamp is exceeded
# ===
#
# Copyright 2013 Needle, Inc (ops@needle.com)
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems'
require 'sensu-plugin/metric/cli'
require 'sensu-plugin/utils'
require 'rest-client'
require 'json'
require 'socket'

include Sensu::Plugin::Utils

class CheckSilenced < Sensu::Plugin::Metric::CLI::Graphite

  default_host = settings['api']['host'] rescue 'localhost' # rubocop:disable RescueModifier

  option :host,
    :short => '-h HOST',
    :long => '--host HOST',
    :description => 'Hostname for sensu-api endpoint',
    :default => default_host

  option :port,
    :short => '-p PORT',
    :long => '--port PORT',
    :description => 'Port for sensu-api endpoint',
    :default => 4567

  option :use_ssl,
    :short => '--ssl',
    :long => '--use-ssl',
    :description => 'Use ssl when connecting to sensu-api endpoint',
    :default => false

  option :scheme,
    :short => '-s SCHEME',
    :long => '--scheme SCHEME',
    :description => 'Metric naming scheme, text to prepend to metric',
    :default => "#{Socket.gethostname}.sensu.stashes.expired"

  option :filter,
    :short => '-f PREFIX',
    :long => '--filter PREFIX',
    :description => 'Stash prefix filter',
    :default => 'silence'

  option :noop,
    :short => '-n',
    :long => '--noop',
    :description => 'Do not delete expired stashes',
    :default => false

  def api
    endpoint = URI.parse("http://#{@config[:host]}:#{@config[:port]}")
    @config[:use_ssl?] ? endpoint.scheme = 'https' : endpoint.scheme = 'http'
    @api ||= RestClient::Resource.new(endpoint, :timeout => 45)
  end

  def get_stashes
    begin
      all_stashes = JSON.parse(api['/stashes'].get)
      filtered_stashes = []
      all_stashes.each do |stash|
        filtered_stashes << stash if stash['path'].match(/^#{@config[:filter]}\/.*/)
      end
      return filtered_stashes
    rescue Errno::ECONNREFUSED
      warning 'Connection refused'
    rescue RestClient::RequestTimeout
      warning 'Connection timed out'
    rescue JSON::ParserError
      warning 'Sensu API returned invalid JSON'
    end
  end

  def delete_stash(stash)
    api["/stash/#{stash['path']}"].delete
  end

  def run
    @config = config
    stashes = get_stashes
    now = Time.now.to_i
    @count = 0
    if stashes.count > 0
      stashes.each do |stash|
        if stash['content'].has_key?('expires') && now - stash['content']['expires'] > 0
          delete_stash(stash) unless config[:noop]
          @count += 1
        end
      end
    end
    ok "#{config[:scheme]}.sensu.stashes.expired", @count
  end

end
