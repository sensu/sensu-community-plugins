#!/usr/bin/env ruby
# Check-qmailq
# ===
#
# This is a simple check script which checks the number of mails in qmail queue for Sensu,
# Uses `qmail-qread` binary to find out the mals in queue
#
# Examples:
#
#   check-qmailq.rb -h host -w warn -c critcal -t type
#
#   Type can be "local" and "remote"
#
#  Author Deepak Mohan Dass   <deepakmdass88@gmail.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'

class CheckQMAILQ < Sensu::Plugin::Check::CLI

  option :host,
    :short => '-h host',
    :default => "127.0.0.1"

  option :warn,
    :short => '-w warn',
    :default => "100"

  option :critical,
    :short => '-c critical',
    :default => "200"

  option :type,
    :short => '-t type',
    :default => "remote"

  def checkq (qtype)
    queue= `/var/qmail/bin/qmail-qread | grep #{qtype} | grep -v done | wc -l`
    queue.to_i
  end

  def run
    msg_ct = checkq("#{config[:type]}")
    if msg_ct >= "#{config[:critical]}".to_i
      critical "#{msg_ct} messages in the #{config[:type]} queue"
    elsif msg_ct >= "#{config[:warn]}".to_i
      warning "#{msg_ct} messages in the #{config[:type]} queue"
    else
      ok "#{msg_ct} messages in the #{config[:type]} queue"
    end
  end
end
