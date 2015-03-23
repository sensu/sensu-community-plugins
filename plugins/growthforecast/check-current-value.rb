#! /usr/bin/env ruby
#
#   check-current-value
#
# DESCRIPTION:
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
#   gem: net/http
#   gem: net/https
#
# USAGE:
#   check-current-value.rb -u "http://growthforecast.host" -i "service/section/name" -w 70 -c 90
#
# LICENSE:
#   Copyright 2015 hirocaster <hohtsuka@gmail.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'json'
require 'uri'
require 'net/http'
require 'net/https'

class CheckCurrentValue < Sensu::Plugin::Check::CLI
  option :url,
         short: '-u URL',
         long: '--url URL',
         description: 'GrowthForecast URL'

  option :item,
         short: '-i service/section/name',
         long: '--item service/section/name',
         description: 'target graf path and name'

  option :direction,
         short: '-d upward or downward',
         long: '--direction upward',
         description: 'switch upward(grather than) or downward(less than)',
         default: 'upward'

  option :warning,
         short: '-w WARNING_VALUE',
         long: '--warning WARNING_VALUE',
         description: 'Alert warning grather(less) than this value',
         default: 70.0

  option :critical,
         short: '-c CRITICAL_VALUE',
         long: '--critical CRITICAL_VALUE',
         description: 'Alert critical grather(less) than this value',
         default: 90.0

  option :user,
         short: '-U USER',
         long: '--username USER',
         description: 'Basic Auth user name(option)'

  option :password,
         short: '-p PASS',
         long: '--password PASS',
         description: 'Basic Auth password(option)'

  option :http_proxy,
         short: '-P HTTP_PROXY_URL',
         long: '--http_proxy HTTP_PROXY_URL',
         description: 'http proxy(option)'

  def run
    case config[:direction]
    when 'upward'
      check_upward
    when 'downward'
      check_downward
    else
      unknown "Error direction option 'upward' or 'downward'"
    end
  end

  def current_value
    return @result if @result

    uri = URI.parse config[:url]

    http = if config[:http_proxy]
             proxy_uri = URI.parse(config[:http_proxy])
             proxy_user, proxy_pass = proxy_uri.userinfo.split(/:/) if uri.userinfo
             Net::HTTP::Proxy(proxy_uri.host, proxy_uri.port, proxy_user, proxy_pass).start(uri.host)
           else
             Net::HTTP.new(uri.host, uri.port)
           end

    if uri.scheme == 'https'
      http.use_ssl = true
    end

    req = Net::HTTP::Get.new("#{uri.path}/summary/#{config[:item]}")

    if !config[:user].nil? && !config[:password].nil?
      req.basic_auth config[:user], config[:password]
    end

    res = http.request(req)

    if /^2/ =~ res.code
      begin
        @result = JSON.parse(res.body)[config[:item]][0].to_f
        @result
      rescue JSON::ParserError
        critical 'JSON Parse Error'
      end
    else
      critical res.code
    end
  end

  def check_upward
    if current_value >= critical_value
      critical "Critical - #{current_info_message}, greather than #{critical_value}"
    elsif current_value >= warning_value
      warning "Warning - #{current_info_message}, grather than #{warning_value}"
    else
      ok success_message
    end
  end

  def check_downward
    if current_value <= critical_value
      critical "Critical - #{current_info_message}, less than #{critical_value}"
    elsif current_value <= warning_value
      warning "Warning - #{current_info_message}, less than #{warning_value}"
    else
      ok success_message
    end
  end

  def warning_value
    config[:warning].to_f
  end

  def critical_value
    config[:critical].to_f
  end

  def current_info_message
    "current value is #{current_value}"
  end

  def success_message
    "Success - #{current_info_message}"
  end
end
