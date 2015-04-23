#! /opt/sensu/embedded/bin/ruby
#
#   check-http-html
#
# DESCRIPTION: Performs an html level check.
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: nokogiri
#   gem: net/http
#
# USAGE:
#
# LICENSE:
#   Copyright 2014 Alexis Bazinet-Deschamps <alexis.bazinet@gmail.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems'
require 'sensu-plugin/check/cli'
require 'nokogiri'
require 'net/http'
require 'net/https'

class CheckHtml < Sensu::Plugin::Check::CLI
  option :url, short: '-u URL', long: '--url URL'
  option :user, short: '-U', long: '--username USER'
  option :password, short: '-a', long: '--password PASS'
  option :timeout, short: '-t SECS', long: '--timeout', proc: proc(&:to_i), default: 15
  option :xpath, short: '-x XPATH', long: '--xpath XPATH'
  option :regex, short: '-r REGEX', long: '--regex REGEX'
  option :validate, short: '-v VALIDATE', long: '--validate VALIDATE', boolean: true, default: false

  def run
    if config[:url]
      uri = URI.parse(config[:url])
      config[:host] = uri.host
      config[:path] = uri.path
      config[:query] = uri.query
      config[:port] = uri.port
      config[:ssl] = uri.scheme == 'https'
    else
      unknown 'No URL specified'
    end

    begin
      timeout(config[:timeout]) do
        acquire_resource
      end
    rescue Timeout::Error
      critical 'Connection timed out'
    rescue => e
      critical "Connection error: #{e.message}"
    end
  end

  def html_malformed_xml?(str)
    Nokogiri::XML(str) { |config| config.strict }
    return false
  rescue Nokogiri::XML::SyntaxError
    return true
  end

  def acquire_resource
    http = Net::HTTP.new(config[:host], config[:port])
    req = Net::HTTP::Get.new([config[:path], config[:query]].compact.join('?'))
    if !config[:user].nil? && !config[:password].nil?
      req.basic_auth config[:user], config[:password]
    end
    res = http.request(req)

    redirects = 0
    while redirects < 100 and res.code =~ /^3/
      req = Net::HTTP::Get.new(URI.parse(res.header['Location']))
      res = http.request(req)
      redirects = redirects + 1
    end

    case res.code
    when /^2/
      if config[:validate] and html_malformed_xml?(res.body)
        critical 'Malformed html response'
      elsif config[:xpath]
        html = Nokogiri::HTML(res.body)
        matches = html.xpath(config[:xpath]).map{|x| x.to_s}

        if matches.empty?
          critical 'Xpath miss'
        elsif config[:regex]
          if matches.all?{ |x| x =~ /#{config[:regex]}/ }
            ok 'Pattern match against the xpath results'
          else
            critical matches.select{ |x| x !~ /#{config[:regex]}/ }
          end
        else
          ok 'Xpath match'
        end
      else
        ok 'Html received'
      end
    else
      critical res.code
    end
  end
end
