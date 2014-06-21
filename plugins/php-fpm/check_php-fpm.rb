#!/usr/bin/env ruby
#
# Check PHP-FPM
# ===
#
# DESCRIPTION:
# This plugin retrives php-fpm status, parse the default "pong response"
#
# PLATFORMS:
# all
#
# DEPENDENCIES:
# sensu-plugin Ruby gem
# php-fpm ping configuration
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'net/http'
require 'uri'
require 'socket'

class CheckPHPFpm < Sensu::Plugin::Check::CLI

  option :pool,
    :short => "-p POOL",
    :long => "--pool POOL",
    :description => "Full POOL name to fpm ping page, example: https://yoursite.com/fpm-ping?pool=POOL",
    :default => "www-data"

  option :hostname,
    :short => "-h HOSTNAME",
    :long => "--host HOSTNAME",
    :description => "Nginx hostname",
    :default => 'localhost'

  option :port,
    :short => "-P PORT",
    :long => "--port PORT",
    :description => "Nginx  port",
    :default => "80"

  option :path,
    :short => "-q PATH",
    :long => "--statspath PATH",
    :description => "Path to your fpm ping",
    :default => "fpm-ping?pool="

  option :scheme,
    :description => "Metric naming scheme, text to prepend to metric",
    :short => "-s SCHEME",
    :long => "--scheme SCHEME",
    :default => "http://"

  option :response,
    :description => "Reponse of ping",
    :short => "-r RESPONSE",
    :long => "--response RESPONSE",
    :default => "pong"

  def run

    config[:url] = config[:scheme] + config[:hostname].to_s + ':' + config[:port].to_s + '/' + config[:path].to_s + config[:pool].to_s
    config[:fqdn] = Socket.gethostname
    uri = URI.parse(config[:url])

    request = Net::HTTP::Get.new(uri.request_uri)
    http = Net::HTTP.new(uri.host, uri.port)
    response = http.request(request)

    if response.code=="200"
      if response.body == config[:response]
        ok "#{config[:response]}"
      else
        critical "#{response.body} instead of #{config[:response]}"
      end
    elsif
      critical "Error, http response code: #{response.code}"
    end

    # be safe
    critical "unknown error"
  end
end
