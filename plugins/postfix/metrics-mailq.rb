#!/usr/bin/env ruby
#
# Postfix Mailq metrics
# ===
#
# Fetch message count metrics from Postfix Mailq.
#
# Example
# -------
#
# $ ./metrics-mailq.rb --scheme servers.hostname
#  servers.hostname.postfixMailqCount     3333    1409060355
#
# Acknowledgements
# ----------------
#
# Copyright 2014 Matt Mencel <https://github.com/MattMencel>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'socket'

class PostfixMailqMetrics < Sensu::Plugin::Metric::CLI::Graphite
  option :path,
         short: '-p MAILQ_PATH',
         long: '--path MAILQ_PATH',
         description: 'Path to the postfix mailq binary.  Defaults to /usr/bin/mailq',
         default: '/usr/bin/mailq'

  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         default: "#{Socket.gethostname}.tcp"

  def run
    timestamp = Time.now.to_i
    queue = `#{config[:path]} | /bin/egrep '[0-9]+ Kbytes in [0-9]+ Request\|Mail queue is empty'`
    # Set the number of messages in the queue
    if queue == 'Mail queue is empty'
      num_messages = 0
    else
      num_messages = queue.split(' ')[4].to_i
    end
    graphite_name = config[:scheme] + '.postfixMailqCount'
    output "#{graphite_name}", num_messages, timestamp
    ok
  end
end
