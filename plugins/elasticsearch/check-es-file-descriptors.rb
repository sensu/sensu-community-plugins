#! /usr/bin/env ruby
#
#   check-es-file-descriptors
#
# DESCRIPTION:
#   This plugin checks the ElasticSearch file descriptor usage, using its API.
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
#   gem: rest-client
#
# USAGE:
#   #YELLOW
#
# NOTES:
#
# LICENSE:
#   Author: S. Zachariah Sprackett <zac@sprackett.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'rest-client'
require 'json'

class ESClusterStatus < Sensu::Plugin::Check::CLI
  option :host,
         description: 'Elasticsearch host',
         short: '-h HOST',
         long: '--host HOST',
         default: 'localhost'

  option :port,
         description: 'Elasticsearch port',
         short: '-p PORT',
         long: '--port PORT',
         proc: proc(&:to_i),
         default: 9200

  option :timeout,
         description: 'Sets the connection timeout for REST client',
         short: '-t SECS',
         long: '--timeout SECS',
         proc: proc(&:to_i),
         default: 30

  option :critical,
         description: 'Critical percentage of FD usage',
         short: '-c PERCENTAGE',
         proc: proc(&:to_i),
         default: 90

  option :warning,
         description: 'Warning percentage of FD usage',
         short: '-w PERCENTAGE',
         proc: proc(&:to_i),
         default: 80

  def get_es_resource(resource)
    r = RestClient::Resource.new("http://#{config[:host]}:#{config[:port]}/#{resource}", timeout: config[:timeout])
    JSON.parse(r.get)
  rescue Errno::ECONNREFUSED
    warning 'Connection refused'
  rescue RestClient::RequestTimeout
    warning 'Connection timed out'
  end

  def acquire_open_fds
    stats = get_es_resource('/_nodes/_local/stats?process=true')
    begin
      keys = stats['nodes'].keys
      stats['nodes'][keys[0]]['process']['open_file_descriptors'].to_i
    rescue NoMethodError
      warning 'Failed to retrieve open_file_descriptors'
    end
  end

  def acquire_max_fds
    info = get_es_resource('/_nodes/_local?process=true')
    begin
      keys = info['nodes'].keys
      info['nodes'][keys[0]]['process']['max_file_descriptors'].to_i
    rescue NoMethodError
      warning 'Failed to retrieve max_file_descriptors'
    end
  end

  def run
    open = acquire_open_fds
    max = acquire_max_fds
    used_percent = ((open.to_f / max.to_f) * 100).to_i

    if used_percent >= config[:critical]
      critical "fd usage #{used_percent}% exceeds #{config[:critical]}% (#{open}/#{max})"
    elsif used_percent >= config[:warning]
      warning "fd usage #{used_percent}% exceeds #{config[:warning]}% (#{open}/#{max})"
    else
      ok "fd usage at #{used_percent}% (#{open}/#{max})"
    end
  end
end
