#!/usr/bin/env ruby
#
# Copyright 2011 Sonian, Inc <chefs@sonian.net>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
require 'librato/metrics'

class LibratoMetrics < Sensu::Handler

  # override filters from Sensu::Handler. not appropriate for metric handlers
  def filter; end

  def handle
    hostname = @event['client']['name'].split('.').first
    check_name = @event['check']['name'].gsub(%r|[ \.]|, '_')
    metric = "sensu.events.#{hostname}.#{check_name}.occurrences"
    value = @event['action'] == 'create' ? @event['occurrences'] : 0

    Librato::Metrics.authenticate settings['librato']['email'], settings['librato']['api_key']

    begin
      timeout(3) do
        Librato::Metrics.submit metric.to_sym => {:type => :counter, :value => value, :source => 'sensu'}
      end
    rescue Timeout::Error
      puts "librato -- timed out while sending metric #{metric}"
    rescue => error
      puts "librato -- failed to send metric #{metric} : #{error}"
    end
  end

end
