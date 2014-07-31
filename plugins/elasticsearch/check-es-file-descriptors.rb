#!/usr/bin/env ruby
#
# Checks ElasticSearch file descriptor status
# ===
#
# DESCRIPTION:
#   This plugin checks the ElasticSearch file descriptor usage, using its API.
#
# OUTPUT:
#   plain-text
#
# PLATFORMS:
#   all
#
# DEPENDENCIES:
#   sensu-plugin Ruby gem
#   rest-client Ruby gem
#
# Author: S. Zachariah Sprackett <zac@sprackett.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'rest-client'
require 'json'

class ESClusterStatus < Sensu::Plugin::Check::CLI
  option :server,
    :description => 'Elasticsearch server',
    :short => '-s SERVER',
    :long => '--server SERVER',
    :default => 'localhost'

  option :critical,
    :description => 'Critical percentage of FD usage',
    :short       => '-c PERCENTAGE',
    :proc        => proc { |a| a.to_i },
    :default     => 90

  option :warning,
    :description => 'Warning percentage of FD usage',
    :short       => '-w PERCENTAGE',
    :proc        => proc { |a| a.to_i },
    :default     => 80

  def get_es_resource(resource)
    begin
      r = RestClient::Resource.new("http://#{config[:server]}:9200/#{resource}", :timeout => 45)
      JSON.parse(r.get)
    rescue Errno::ECONNREFUSED
      warning 'Connection refused'
    rescue RestClient::RequestTimeout
      warning 'Connection timed out'
    end
  end

  def get_open_fds
    stats = get_es_resource('/_nodes/_local/stats?process=true')
    begin
      keys = stats['nodes'].keys
      stats['nodes'][keys[0]]['process']['open_file_descriptors'].to_i
    rescue NoMethodError
      warning "Failed to retrieve open_file_descriptors"
    end
  end

  def get_max_fds
    info = get_es_resource('/_nodes/_local?process=true')
    begin
      keys = info['nodes'].keys
      info['nodes'][keys[0]]['process']['max_file_descriptors'].to_i
    rescue NoMethodError
      warning "Failed to retrieve max_file_descriptors"
    end
  end

  def run
    open = get_open_fds
    max = get_max_fds
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
