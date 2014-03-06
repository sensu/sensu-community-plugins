#!/usr/bin/env ruby
#
# RblCheck
# ===
#
# Checks if a ip is blacklisted in the common dns blacklists. You can
# add a list
#
# Required gems:  dnsbl-client
#
# of dnsbls which you donot wish to check against by option -I followed
# by Comma Separated
# value (string) of the blnames. Also you can set certain important
# blacklists as critical by -C option in a similar way.
#
# EXAMPLE USAGE:
#   check-rbl.rb -i 8.8.8.8 -C SORBS -I UCEPROTECT3
#
# Copyright 2012 Sarguru Nathan  <sarguru90@gmail.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'dnsbl-client'
require 'set'

class RblCheck < Sensu::Plugin::Check::CLI

  option :ip,
    :short => '-i IPADDRESS',
    :long  => '--ip IPADDRESS',
    :description => 'IP of the server to check'

  option :ignored_bls,
    :short => '-I BLACKLISTNAME',
    :long  => '--ignored_bls BLACKLISTNAME',
    :description => 'Comma Separated String of ignored blacklists from default list',
    :default => 'null'

  option :critical_bls,
    :short => '-C BLACKLISTNAME',
    :long  => '--critical_bls BLACKLISTNAME',
    :description => 'Comma Separated String of critical blacklists from default list',
    :default => 'null'

  def run
    c = DNSBL::Client.new

    if config[:ip]
      ip_add = config[:ip]
    else
      critical "plugin failed. Required Argument -i (ip address of the client)"
    end

    if config[:ignored_bls]
      ignored_bls = config[:ignored_bls]
      ignored_bls_set = ignored_bls.split(',').to_set
    end

    if config[:critical_bls]
      critical_bls = config[:critical_bls]
      critical_bls_set = critical_bls.split(',').to_set
    end

    dnsbl_ret   = c.lookup("#{ip_add}")
    msg_string  = ""
    criticality = 0

    dnsbl_ret.each do |dnsbl_result|

      if (dnsbl_result.meaning =~ /spam/i || dnsbl_result.meaning =~ /blacklist/i)
        unless (ignored_bls_set.member?(dnsbl_result.dnsbl))
          msg_string =  "#{msg_string} #{dnsbl_result.dnsbl}"
        end

        if (critical_bls_set.member?(dnsbl_result.dnsbl))
          criticality += 1
        end
      end

    end

    unless msg_string.empty?
      if (criticality > 0)
        critical "#{ip_add} Blacklisted in#{msg_string}"
      else
        warning "#{ip_add} Blacklisted in#{msg_string}"
      end
    else
      msg_txt = "All is well. #{ip_add} has good reputation."
      ok "#{msg_txt}"
    end

  end
end
