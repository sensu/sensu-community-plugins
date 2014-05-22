#!/usr/bin/env ruby
#
# Passenger Metrics Plugin
# ===
#
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'socket'
require 'sensu-plugin/metric/cli'

class PassengerApacheMetrics < Sensu::Plugin::Metric::CLI::Graphite

  option :scheme,
    :description => "Metric naming scheme, text to prepend to queue_name.metric",
    :short => "-s SCHEME",
    :long => "--scheme SCHEME",
    :default => "#{Socket.gethostname}.passenger"

  def run
        apache_count = `sudo passenger-memory-stats | sed -n '/^-* Apache processes -*$/,/^$/p' | grep '/apache2 ' | wc -l`
        passenger_count = `sudo passenger-memory-stats | sed -n '/^-* Passenger processes -*$/,/^$/p'|grep 'Passenger R'|grep -v grep|wc -l`
        passenger_queue = `sudo passenger-status|grep 'Requests in queue'| awk '{print $4}'`

        output "#{config[:scheme]}.apache_process_count", apache_count
        output "#{config[:scheme]}.passenger_process_count", passenger_count
        output "#{config[:scheme]}.passenger_queue_count", passenger_queue

        ok
  end

end
