#!/usr/bin/env ruby
#
# Check when a SSL certificate will expire.
# ===
#
# Requirements
# ===
#
# Needs the openssl binary on the system.
#
# Jean-Francois Theroux <me@failshell.io>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'date'
require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'

class CheckSSLCert < Sensu::Plugin::Check::CLI

  option :critical,
    :description => 'Numbers of days left',
    :short => '-c',
    :long => '--critical DAYS',
    :required => true

  option :warning,
    :description => 'Numbers of days left',
    :short => '-w',
    :long => '--warning DAYS',
    :required => true

  option :host,
    :description => 'Host to validate',
    :short => '-h',
    :long => '--host HOST',
    :required => true

  option :port,
    :description => 'Port to validate',
    :short => '-p',
    :long => '--port PORT',
    :required => true

  def check_ssl_cert_expiration
    expire = `openssl s_client -connect #{config[:host]}:#{config[:port]} < /dev/null 2>&1 | openssl x509 -enddate -noout`.split('=').last
    days_until = (Date.parse(expire) - Date.today).to_i
    if days_until < 0
      critical "Expired #{days_until.abs} days ago - #{config[:host]}:#{config[:port]}"
    elsif days_until < config[:critical].to_i
      critical "#{days_until} days left - #{config[:host]}:#{config[:port]}"
    elsif days_until < config[:warning].to_i
      warning "#{days_until} days left - #{config[:host]}:#{config[:port]}"
    else
      ok "#{days_until} days left - #{config[:host]}:#{config[:port]}"
    end
  end

  def run
    check_ssl_cert_expiration
  end

end
