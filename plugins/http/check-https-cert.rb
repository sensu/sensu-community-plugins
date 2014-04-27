#!/usr/bin/env ruby
#
# DESCRIPTION:
#    Checks the expiration date of a URL SSL Certificate
#    and notifies if it is before the expiry parameter.
#
# DEPENDENCIES:
#   sensu-plugin Ruby gem
#   net-https    Ruby stdlib
#
# Copyright 2014 Rhommel Lamas <roml@rhommell.com>
#
# Released under the same terms as Sensu (the MIT license) ; see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'net/https'

class CheckHTTP < Sensu::Plugin::Check::CLI

  option :url,
    :short => '-u URL',
    :long => '--url URL',
    :proc => proc { |i| i.to_s },
    :description => 'A URL to connect to'

  option :expiry,
    :short => '-e EXPIRY',
    :long => '--e EXPIRY',
    :proc => proc { |a| a.to_i },
    :description => 'Warn EXPIRE days before cert expires'

  def run
    begin
      uri = URI.parse(config[:url])
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_PEER

      http.start do |h|
        @cert = h.peer_cert
      end
      expire_warn_date = Time.now + (config[:expiry] * 60 * 60 * 24)

      if @cert.not_after > expire_warn_date
        ok "SSL expires on #{@cert.not_after}."
      else
        warning "SSL expires on #{@cert.not_after}."
      end

    rescue
      message "Could not connect to #{config[:url]}"
      exit 1
    end
  end
end
