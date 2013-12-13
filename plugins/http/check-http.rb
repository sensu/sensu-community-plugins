#!/usr/bin/env ruby
#
# Check HTTP
# ===
#
# Takes either a URL or a combination of host/path/port/ssl, and checks for
# a 200 response (that matches a pattern, if given). Can use client certs.
#
# Copyright 2011 Sonian, Inc <chefs@sonian.net>
# Updated by Lewis Preson 2012 to accept basic auth credentials
# Updated by SweetSpot 2012 to require specified redirect
# Updated by Chris Armstrong 2013 to accept multiple headers
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'net/http'
require 'net/https'

class CheckHTTP < Sensu::Plugin::Check::CLI

  option :ua, :short => '-x USER-AGENT', :long => '--user-agent USER-AGENT', :default => 'Sensu-HTTP-Check'
  option :url, :short => '-u URL'
  option :host, :short => '-h HOST'
  option :request_uri, :short => '-p PATH'
  option :port, :short => '-P PORT', :proc => proc { |a| a.to_i }
  option :header, :short => '-H HEADER', :long => '--header HEADER'
  option :ssl, :short => '-s', :boolean => true, :default => false
  option :insecure, :short => '-k', :boolean => true, :default => false
  option :user, :short => '-U', :long => '--username USER'
  option :password, :short => '-a', :long => '--password PASS'
  option :cert, :short => '-c FILE'
  option :cacert, :short => '-C FILE'
  option :pattern, :short => '-q PAT'
  option :timeout, :short => '-t SECS', :proc => proc { |a| a.to_i }, :default => 15
  option :redirectok, :short => '-r', :boolean => true, :default => false
  option :redirectto, :short => '-R URL'
  option :response_bytes, :long => '--response-bytes BYTES', :proc => proc { |a| a.to_i }

  def run
    if config[:url]
      uri = URI.parse(config[:url])
      config[:host] = uri.host
      config[:port] = uri.port
      config[:request_uri] = uri.request_uri
      config[:ssl] = uri.scheme == 'https'
    else
      unless config[:host] and config[:request_uri]
        unknown 'No URL specified'
      end
      config[:port] ||= config[:ssl] ? 443 : 80
    end

    begin
      timeout(config[:timeout]) do
        get_resource
      end
    rescue Timeout::Error
      critical "Connection timed out"
    rescue => e
      critical "Connection error: #{e.message}"
    end
  end

  def get_resource
    http = Net::HTTP.new(config[:host], config[:port])

    if config[:ssl]
      http.use_ssl = true
      if config[:cert]
        cert_data = File.read(config[:cert])
        http.cert = OpenSSL::X509::Certificate.new(cert_data)
        http.key = OpenSSL::PKey::RSA.new(cert_data, nil)
      end
      if config[:cacert]
        http.ca_file = config[:cacert]
      end
      if config[:insecure]
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE
      end
    end

    req = Net::HTTP::Get.new(config[:request_uri], {'User-Agent' => config[:ua]})

    if (config[:user] != nil and config[:password] != nil)
      req.basic_auth config[:user], config[:password]
    end
    if config[:header]
      config[:header].split(',').each do |header|
        h, v = header.split(':', 2)
        req[h] = v.strip
      end
    end
    res = http.request(req)

    if config[:response_bytes]
      body = "\n" + res.body[1..config[:response_bytes].to_i]
    else
      body = ''
    end

    case res.code
    when /^2/
      if config[:redirectto]
        critical "expected redirect to #{config[:redirectto]} but got #{res.code}" + body
      elsif config[:pattern]
        if res.body =~ /#{config[:pattern]}/
          ok "#{res.code}, found /#{config[:pattern]}/ in #{res.body.size} bytes" + body
        else
          critical "#{res.code}, did not find /#{config[:pattern]}/ in #{res.body.size} bytes: #{res.body[0...200]}..."
        end
      else
        ok "#{res.code}, #{res.body.size} bytes" + body
      end
    when /^3/
      if config[:redirectok] || config[:redirectto]
        if config[:redirectok]
          ok "#{res.code}, #{res.body.size} bytes" + body
        elsif config[:redirectto]
          if config[:redirectto] == res['Location']
            ok "#{res.code} found redirect to #{res['Location']}" + body
          else
            critical "expected redirect to #{config[:redirectto]} instead redirected to #{res['Location']}" + body
          end
        end
      else
        warning res.code + body
      end
    when /^4/, /^5/
      critical res.code + body
    else
      warning res.code + body
    end
  end
end
