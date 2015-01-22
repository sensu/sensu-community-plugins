#!/usr/bin/env ruby
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details
#
# This will send a 1 to a graphite metric when an event is created and 0 when it's resolved
# See http://imansson.wordpress.com/2012/11/26/why-sensu-is-a-monitoring-router-some-cool-handlers/

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
require 'simple-graphite'

class Resolve < Sensu::Handler
  def handle
    port = settings['graphite_notify']['port'] ? settings['graphite_notify']['port'].to_s : '2003'
    graphite = Graphite.new(host: settings['graphite_notify']['host'], port: port)
    return unless graphite
    prop = @event['action'] == 'create' ? 1 : 0
    message = "#{settings['graphite_notify']['prefix']}.#{@event['client']['name'].gsub('.', '_')}.#{@event['check']['name']}"
    message += " #{prop} #{graphite.time_now + rand(100)}"
    begin
      graphite.push_to_graphite do |graphite_socket|
        graphite_socket.puts message
      end
    rescue ETIMEDOUT
      error_msg = "Can't connect to #{settings['graphite_notify']['host']}:#{port} and send message #{message}'"
      raise error_msg
    end
  end
end
