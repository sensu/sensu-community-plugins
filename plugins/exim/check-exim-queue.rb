#!/usr/bin/env ruby
# Check-exim-queue
# ===
#
# This is a simple check script which checks the number of mails in exim queue for Sensu,
# Uses `exim -bpc` binary to find out the mals in queue
#
# (based on check-mailq by Deepak Mohan Dass<deepakmdass88@gmail.com>)
#
# Example:
#
#   check-exim-queue.rb -w warn -c critcal 
#
#  Author Viktor Kovacs   <kovacs.viktor@tarhelypark.hu>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'

class CheckEximQueue < Sensu::Plugin::Check::CLI

  option :warn,
    :short => '-w warn',
    :default => "120"

  option :critical,
    :short => '-c critical',
    :default => "150"

  def check_queue
    return `/usr/sbin/exim -bpc`.to_i
  end

  def run
    msg_ct = check_queue
    if msg_ct >= "#{config[:critical]}".to_i
      critical "#{msg_ct} messages in the #{config[:type]} queue"
    elsif msg_ct >= "#{config[:warn]}".to_i
      warning "#{msg_ct} messages in the #{config[:type]} queue"
    else
      ok "#{msg_ct} messages in the #{config[:type]} queue"
    end
  end
end
