#!/usr/bin/env ruby
# check-ftp.rb
# ===
# Uses either net/ftp or optionally double-bag-ftps ruby gem to check for
# connectivity to an FTP or FTPS server
#
# Author: S. Zachariah Sprackett <zac@sprackett.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'net/http'

class CheckFTP < Sensu::Plugin::Check::CLI
  option :host,
    :short   => '-H HOST',
    :default => 'localhost'
  option :tls,
    :short   => '-s',
    :boolean => true,
    :default => false
  option :noverify,
    :short   => '-n',
    :boolean => true,
    :default => false
  option :user,
    :short   => '-u',
    :long    => '--username USER',
    :default => 'anonymous'
  option :pass,
    :short => '-p',
    :long  => '--password PASS'
  option :timeout,
    :short   => '-t SECS',
    :proc    => proc { |a| a.to_i },
    :default => 15

  def run
    begin
      timeout(config[:timeout]) do
        if config[:tls]
          ftps_login
        else
          ftp_login
        end
      end
    rescue Timeout::Error
      critical "Connection timed out"
    rescue => e
      critical "Connection error: #{e.message}"
    end
    ok
  end

  def ftps_login
    require 'double_bag_ftps'
    verify = OpenSSL::SSL::VERIFY_PEER
    if config[:noverify]
      verify = OpenSSL::SSL::VERIFY_NONE
    end

    begin
      ftps = DoubleBagFTPS.new
      ftps.ssl_context = DoubleBagFTPS.create_ssl_context(
        :verify_mode => verify
      )
      ftps.connect(config[:host])
      ftps.login(config[:user], config[:pass])
      ftps.quit
    rescue => e
      critical "Failed to log in (#{e.to_s.chomp})"
    end
  end

  def ftp_login
    require 'net/ftp'
    begin
      ftp = Net::FTP.new(config[:host])
      ftp.login(config[:user], config[:pass])
      ftp.quit
    rescue => e
      critical "Failed to log in (#{e.to_s.chomp})"
    end
  end
end
