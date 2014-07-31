#!/usr/bin/env ruby
#
# Sensu Logstash Handler
#
# Heavily inspried (er, copied from) the GELF Handler writeen by
# Joe Miller.
#
# Designed to take sensu events, transform them into logstah JSON events
# and ship them to a redis server for logstash to index.  This also
# generates a tag with either 'sensu-ALERT' or 'sensu-RECOVERY' so that
# searching inside of logstash can be a little easier.
#
# Written by Zach Dunn -- @SillySophist or http://github.com/zadunn
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
require 'redis'
require 'json'
require 'socket'
require 'time'

class LogstashHandler < Sensu::Handler

  def event_name
    @event['client']['name'] + '/' + @event['check']['name']
  end

  def action_to_string
    @event['action'].eql?('resolve') ? "RESOLVE" : "ALERT"
  end

  def handle
    redis = Redis.new(:host => settings['logstash']['server'], :port => settings['logstash']['port'])
    time = Time.now.utc.iso8601
    logstash_msg = {
      :@timestamp => time,
      :@version => 1,
      :source => ::Socket.gethostname,
      :tags => ["sensu-#{action_to_string}"],
      :message => @event['check']['output'],
      :host          => @event['client']['name'],
      :timestamp     => @event['check']['issued'],
      :address       => @event['client']['address'],
      :check_name    => @event['check']['name'],
      :command       => @event['check']['command'],
      :status        => @event['check']['status'],
      :flapping      => @event['check']['flapping'],
      :occurrences   => @event['occurrences'],
      :flapping      => @event['check']['flapping'],
      :occurrences   => @event['occurrences'],
      :action        => @event['action']
    }
    logstash_msg[:type] = settings['logstash']['type'] if settings['logstash'].has_key?('type')
    redis.lpush(settings['logstash']['list'], logstash_msg.to_json)
  end
end
