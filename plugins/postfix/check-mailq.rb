#!/usr/bin/env ruby
#
# Check the size of the postfix mail queue
# ===
#
# Copyright (c) 2013, Justin Lambert <jlambert@letsevenup.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'

class PostfixMailq < Sensu::Plugin::Check::CLI
  option :path,
         short: '-p MAILQ_PATH',
         long: '--path MAILQ_PATH',
         description: 'Path to the postfix mailq binary.  Defaults to /usr/bin/mailq',
         default: '/usr/bin/mailq'

  option :warning,
         short: '-w WARN_NUM',
         long: '--warnnum WARN_NUM',
         description: 'Number of messages in the queue considered to be a warning',
         required: true

  option :critical,
         short: '-c CRIT_NUM',
         long: '--critnum CRIT_NUM',
         description: 'Number of messages in the queue considered to be critical',
         required: true

  def run
    # mailq will either end with a summary line (-- 11 Kbytes in 31 Requests.)
    # or 'Mail queue is empty'.  Using grep rather than returning the entire
    # list since that could consume a significant amount of memory.
    queue = `#{config[:path]} | /bin/egrep '[0-9]+ Kbytes in [0-9]+ Request\|Mail queue is empty'`

    # Set the number of messages in the queue
    if queue == 'Mail queue is empty'
      num_messages = 0
    else
      num_messages = queue.split(' ')[4].to_i
    end

    if num_messages >= config[:critical].to_i
      critical "#{num_messages} messages in the postfix mail queue"
    elsif num_messages >= config[:warning].to_i
      warning "#{num_messages} messages in the postfix mail queue"
    else
      ok "#{num_messages} messages in the postfix mail queue"
    end
  end
end
