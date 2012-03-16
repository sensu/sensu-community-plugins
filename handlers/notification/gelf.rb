#!/usr/bin/env ruby
#
# Sensu GELF Handler
# ===
#
# This handler packages alerts into GELF messages and passes them
# to a Graylog2 server (or any other server that can accept GELF.)
# You need to set the options in the gelf.json file which should
# live in your /etc/sensu/conf.d directory. The 'server' and 'port'
# options are mandatory. An example gelf.json file is provided.
#
# Things to note about how GELF messages are constructed:
# ---------------
#  - The 'facility' field is hardcoded to 'sensu'. This may change in the
#    future.
#
#  - The 'short_message' field is modeled after the Twitter handler, thus,
#    when a new alert is created the content will look like:
#     "ALERT - client_hostname/check_name: Check Notification Message",
#    and when an alert is resolved the content will look like:
#     "RESOLVE - client_hostname/check_name: Check Notification Message",
#
#  - The 'level' field is set to GELF::INFO when an alert is resolved,
#    and GELF::FATAL when an alert is created.
#
#  - The Sensu error level (eg: WARNING, CRITICAL) is available in the
#    '_status' field as an integer.
#
# Copyright 2012 Joe Miller (https://github.com/joemiller | http://twitter.com/miller_joe)
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
require 'gelf'

class GelfHandler < Sensu::Handler

  def event_name
    @event['client']['name'] + '/' + @event['check']['name']
  end

  def action_to_string
    @event['action'].eql?('resolve') ? "RESOLVE" : "ALERT"
  end

  def action_to_gelf_level
    @event['action'].eql?('resolve') ? ::GELF::Levels::INFO : ::GELF::Levels::FATAL
  end

  def handle
    @notifier = ::GELF::Notifier.new(settings['gelf']['server'], settings['gelf']['port'])
    gelf_msg = {
      :short_message => "#{action_to_string} - #{event_name}: #{@event['check']['notification']}",
      :full_message  => @event['check']['output'],
      :facility      => 'sensu',
      :level         => action_to_gelf_level,
      :host          => @event['client']['name'],
      :timestamp     => @event['check']['issued'],
      :_address      => @event['client']['address'],
      :_check_name   => @event['check']['name'],
      :_command      => @event['check']['command'],
      :_status       => @event['check']['status'],
      :_flapping     => @event['check']['flapping'],
      :_occurrences  => @event['occurrences'],
      :_action       => @event['action']
    }
    @notifier.notify!(gelf_msg)
  end

end
