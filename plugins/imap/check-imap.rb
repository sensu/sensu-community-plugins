#!/usr/bin/env ruby
# Check-imap
# ===
#
# This is a simple IMAP check script for Sensu, Uses Ruby IMAP library
#  and authenticates with the given credentials
#
# Example:
#
#   check-imap.rb -h host -m mech -u user -p pass  => mech - auth mechanisms
#
# Supported Auth mechanisms "login", "plain", "cram-md5"
#
# Refer your IMAP server settings to find which mechanism to use
#
#  Author Deepak Mohan Dass   <deepakmdass88@gmail.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'net/imap'
require 'timeout'

class CheckIMAP < Sensu::Plugin::Check::CLI

  option :host,
    :short => '-h host',
    :default => "127.0.0.1"

  option :mech,
    :short => '-m mech',
    :default => 'plain'

  option :user,
    :short => '-u user',
    :default => "test"

  option :pass,
    :short => '-p pass',
    :default => "yoda"

  def run
    begin
      Timeout.timeout(15) do
        imap = Net::IMAP.new("#{config[:host]}")
        status = imap.authenticate("#{config[:mech]}", "#{config[:user]}", "#{config[:pass]}")
        unless status == nil
        ok "IMAP SERVICE WORKS FINE"
        imap.disconnect
        end
      end
      rescue Timeout::Error
      critical "IMAP Connection timed out"
      rescue => e
      critical "Connection error: #{e.message}"
    end
  end
end
