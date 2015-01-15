#! /usr/bin/env ruby
#
#   check-http
#
# DESCRIPTION:
#   Takes either a URL or a combination of host/path/port/ssl, and checks for
#   a 200 response (that matches a pattern, if given). Can use client certs.
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: net
#
# USAGE:
#   #YELLOW
#
# NOTES:
#
# LICENSE:
#   Copyright 2011 Sonian, Inc <chefs@sonian.net>
#   Updated by Lewis Preson 2012 to accept basic auth credentials
#   Updated by SweetSpot 2012 to require specified redirect
#   Updated by Chris Armstrong 2013 to accept multiple headers
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'net/http'
require 'net/https'

class CheckHTTP < Sensu::Plugin::Check::CLI
  option :ua,
         short: '-x USER-AGENT',
         long: '--user-agent USER-AGENT',
         description: 'Specify a USER-AGENT',
         default: 'Sensu-HTTP-Check'

  option :url,
         short: '-u URL',
         long: '--url URL',
         description: 'A URL to connect to'

  option :host,
         short: '-h HOST',
         long: '--hostname HOSTNAME',
         description: 'A HOSTNAME to connect to'

  option :port,
         short: '-P PORT',
         long: '--port PORT',
         proc: proc(&:to_i),
         description: 'Select another port',
         default: 80

  option :request_uri,
         short: '-p PATH',
         long: '--request-uri PATH',
         description: 'Specify a uri path'

  option :header,
         short: '-H HEADER',
         long: '--header HEADER',
         description: 'Check for a HEADER'

  option :ssl,
         short: '-s',
         boolean: true,
         description: 'Enabling SSL connections',
         default: false

  option :insecure,
         short: '-k',
         boolean: true,
         description: 'Enabling insecure connections',
         default: false

  option :user,
         short: '-U',
         long: '--username USER',
         description: 'A username to connect as'

  option :password,
         short: '-a',
         long: '--password PASS',
         description: 'A password to use for the username'

  option :cert,
         short: '-c FILE',
         long: '--cert FILE',
         description: 'Cert to use'

  option :cacert,
         short: '-C FILE',
         long: '--cacert FILE',
         description: 'A CA Cert to use'

  option :expiry,
         short: '-e EXPIRY',
         long: '--expiry EXPIRY',
         proc: proc(&:to_i),
         description: 'Warn EXPIRE days before cert expires'

  option :pattern,
         short: '-q PAT',
         long: '--query PAT',
         description: 'Query for a specific pattern'

  option :timeout,
         short: '-t SECS',
         long: '--timeout SECS',
         proc: proc(&:to_i),
         description: 'Set the timeout',
         default: 15

  option :redirectok,
         short: '-r',
         boolean: true,
         description: 'Check if a redirect is ok',
         default: false

  option :redirectto,
         short: '-R URL',
         long: '--redirect-to URL',
         description: 'Redirect to another page'

  option :response_bytes,
         short: '-b BYTES',
         long: '--response-bytes BYTES',
         description: 'Print BYTES of the output',
         proc: proc(&:to_i)

  option :require_bytes,
         short: '-B BYTES',
         long: '--require-bytes BYTES',
         description: 'Check the response contains exactly BYTES bytes',
         proc: proc(&:to_i)

  option :response_code,
         long: '--response-code CODE',
         description: 'Check for a specific response code'

  def run
    if config[:url]
      uri = URI.parse(config[:url])
      config[:host] = uri.host
      config[:port] = uri.port
      config[:request_uri] = uri.request_uri
      config[:ssl] = uri.scheme == 'https'
    else
      # #YELLOW
      unless config[:host] && config[:request_uri] # rubocop:disable IfUnlessModifier
        unknown 'No URL specified'
      end
      config[:port] ||= config[:ssl] ? 443 : 80
    end

    begin
      timeout(config[:timeout]) do
        acquire_resource
      end
    rescue Timeout::Error
      critical 'Request timed out'
    rescue => e
      critical "Request error: #{e.message}"
    end
  end

  def acquire_resource
    http = Net::HTTP.new(config[:host], config[:port])

    warn_cert_expire = nil
    if config[:ssl]
      http.use_ssl = true
      if config[:cert]
        cert_data = File.read(config[:cert])
        http.cert = OpenSSL::X509::Certificate.new(cert_data)
        http.key = OpenSSL::PKey::RSA.new(cert_data, nil)
      end
      http.ca_file = config[:cacert] if config[:cacert]
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE if config[:insecure]

      unless config[:expiry].nil?
        expire_warn_date = Time.now + (config[:expiry] * 60 * 60 * 24)
        # We can't raise inside the callback, have to check when we finish.
        http.verify_callback = proc do |_preverify_ok, ssl_context|
          if ssl_context.current_cert.not_after <= expire_warn_date
            warn_cert_expire = ssl_context.current_cert.not_after
          end
        end
      end
    end

    req = Net::HTTP::Get.new(config[:request_uri], 'User-Agent' => config[:ua])

    if !config[:user].nil? && !config[:password].nil?
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
      body = "\n" + res.body[0..config[:response_bytes]]
    else
      body = ''
    end

    if config[:require_bytes] && res.body.length != config[:require_bytes]
      critical "Response was #{res.body.length} bytes instead of #{config[:require_bytes]}" + body
    end

    unless warn_cert_expire.nil?
      warning "Certificate will expire #{warn_cert_expire}"
    end

    size = res.body.nil? ? '0' : res.body.size

    case res.code
    when /^2/
      if config[:redirectto]
        critical "Expected redirect to #{config[:redirectto]} but got #{res.code}" + body
      elsif config[:pattern]
        if res.body =~ /#{config[:pattern]}/
          ok "#{res.code}, found /#{config[:pattern]}/ in #{size} bytes" + body
        else
          critical "#{res.code}, did not find /#{config[:pattern]}/ in #{size} bytes: #{res.body[0...200]}..."
        end
      else
        ok("#{res.code}, #{size} bytes" + body) unless config[:response_code]
      end
    when /^3/
      if config[:redirectok] || config[:redirectto]
        if config[:redirectok]
          # #YELLOW
          ok("#{res.code}, #{size} bytes" + body) unless config[:response_code] # rubocop:disable BlockNesting
        elsif config[:redirectto]
          # #YELLOW
          if config[:redirectto] == res['Location'] # rubocop:disable BlockNesting
            ok "#{res.code} found redirect to #{res['Location']}" + body
          else
            critical "Expected redirect to #{config[:redirectto]} instead redirected to #{res['Location']}" + body
          end
        end
      else
        warning res.code + body
      end
    when /^4/, /^5/
      critical(res.code + body) unless config[:response_code]
    else
      warning(res.code + body) unless config[:response_code]
  end

    # #YELLOW
    if config[:response_code] # rubocop:disable GuardClause
      if config[:response_code] == res.code
        ok "#{res.code}, #{size} bytes" + body
      else
        critical res.code + body
      end
    end
  end
end
