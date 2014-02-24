#!/usr/bin/env ruby
#
# ===
#
# DESCRIPTION:
#   This plugin looks up all ELBs in the organization and checks https
#   endpoints for expiring certificates
#
# PLATFORMS:
#   all
#
# DEPENDENCIES:
#   sensu-plugin >= 1.5 Ruby gem
#   aws-sdk Ruby gem
#
# Copyright (c) 2013, Peter Burkholder, pburkholder@pobox.com
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'aws-sdk'
require 'net/http'
require 'openssl'

class CheckELBCerts < Sensu::Plugin::Check::CLI

  option :aws_access_key,
    :short => '-a AWS_ACCESS_KEY',
    :long => '--aws-access-key AWS_ACCESS_KEY',
    :description => "AWS Access Key. Either set ENV['AWS_ACCESS_KEY_ID'] or provide it as an option",
    :default => ENV['AWS_ACCESS_KEY_ID']

  option :aws_secret_access_key,
    :short => '-s AWS_SECRET_ACCESS_KEY',
    :long => '--aws-secret-access-key AWS_SECRET_ACCESS_KEY',
    :description => "AWS Secret Access Key. Either set ENV['AWS_SECRET_ACCESS_KEY'] or provide it as an option",
    :default => ENV['AWS_SECRET_ACCESS_KEY']

  option :aws_region,
    :short => '-r AWS_REGION',
    :long => '--aws-region REGION',
    :description => "AWS Region (such as eu-west-1).",
    :default => 'us-east-1'

  option :warn_under,
    :short  => '-w WARN_NUM',
    :long  => '--warn WARN_NUM',
    :description => 'Warn on minimum number of days to SSL/TLS certificate expiration',
    :default => 30,
    :proc => proc { |a| a.to_i }

  option :crit_under,
    :short  => '-c CRIT_NUM',
    :long  => '--crit CRIT_NUM',
    :description => 'Minimum number of days to SSL/TLS certificate expiration',
    :default => 5,
    :proc => proc { |a| a.to_i }

  option :verbose,
    :short  => '-v',
    :long  => '--verbose',
    :description => 'Provide SSL/TLS certificate expiration details even when OK',
    :default => false

  def cert_message(count, descriptor, limit)
    message = (count == 1 ? "1 ELB cert is " : "#{count} ELB certs are ")
    message += "#{descriptor} #{limit} day"
    message += (limit == 1 ? "" : "s") # rubocop:disable UselessAssignment
  end

  def run
    ok_message = []
    warning_message = []
    critical_message = []

    AWS.start_memoizing

    elb = AWS::ELB.new(
      :access_key_id      => config[:aws_access_key],
      :secret_access_key  => config[:aws_secret_access_key],
      :region             => config[:aws_region])

    begin
      elb.load_balancers.each do |lb|
        lb.listeners.each do |listener|
          if (listener.protocol.to_s == 'https')
            url = URI.parse("https://#{lb.dns_name}:#{listener.port}")
            http = Net::HTTP.new(url.host, url.port)
            http.use_ssl = true
            http.verify_mode = OpenSSL::SSL::VERIFY_NONE
            cert = ""

            begin
              http.start { cert = http.peer_cert }
            rescue Exception => e
              critical "An issue occurred attempting to get cert: #{e.message}"
            end

            cert_days_remaining = ((cert.not_after - Time.now) / 86400).to_i
            message = sprintf '%s(%d)', lb.name, cert_days_remaining

            if config[:crit_under] > 0 && config[:crit_under] >= cert_days_remaining
              critical_message << message
            elsif config[:warn_under] > 0 && config[:warn_under] >= cert_days_remaining
              warning_message << message
            else
              ok_message << message
            end
          end
        end
      end
    rescue Exception => e
      unknown "An error occurred processing AWS ELB API: #{e.message}"
    end

    if critical_message.length > 0
      message = cert_message(critical_message.length, "expiring within", config[:crit_under])
      message += ": " + critical_message.sort.join(' ')
      critical message
    elsif warning_message.length > 0
      message = cert_message(warning_message.length, "expiring within", config[:warn_under])
      message += ": " + warning_message.sort.join(' ')
      warning message
    else
      message = cert_message(ok_message.length, "valid for at least", config[:warn_under])
      message += ": " + ok_message.sort.join(' ') if config[:verbose]
      ok message
    end
  end

end
