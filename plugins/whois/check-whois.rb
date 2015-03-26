#!/usr/bin/env ruby
# encoding: utf-8
#
#   check-whois
#
# DESCRIPTION:
#   This plugin checks domain expiration dates using the 'whois' gem.
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Tested on Mac OS X
#
# DEPENDENCIES:
#   gem: whois
#
# USAGE:
#   $ ./check-whois.rb -d mijit.com
#   WhoisCheck OK: mijit.com expires on 02-07-2016 (325 days away)
#
# LICENSE:
#   Copyright 2015 michael j talarczyk <mjt@mijit.com> and contributors.
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.

require 'sensu-plugin/check/cli'
require 'whois'

class WhoisCheck < Sensu::Plugin::Check::CLI
  option :domain,
         short: '-d DOMAIN',
         long: '--domain DOMAIN',
         required: true,
         description: 'Domain to check'

  option :warning,
         short: '-w DAYS',
         long: '--warn DAYS',
         default: 30,
         description: 'Warn if fewer than DAYS away'

  option :critical,
         short: '-c DAYS',
         long: '--critical DAYS',
         default: 7,
         description: 'Critical if fewer than DAYS away'

  option :help,
         short: '-h',
         long: '--help',
         description: 'Show this message',
         on: :tail,
         boolean: true,
         show_options: true,
         exit: 0

  def check_expiration(num_days,
                       warning_days=config[:warning].to_i,
                       critical_days=config[:critical].to_i)
    case
    when num_days <= critical_days
      critical
    when num_days <= warning_days
      warning
    else
      ok
    end
  end

  def initialize
    super()
    whois = Whois.whois(config[:domain])
    @expires_on = DateTime.parse(whois.expires_on.to_s)
    @num_days = (@expires_on - DateTime.now).to_i
  end

  def run
    message "#{ config[:domain] } expires on #{ @expires_on.strftime('%m-%d-%Y') } (#{ @num_days } days away)"
    check_expiration @num_days
  end
end
