# !/usr/bin/env ruby
# https://getsentry.com/welcome/
# sentry aggregates events and makes them EASILY searchable
# as well as can send notifications for certain events etc...
# https://github.com/getsentry/sentry
# sends events to sentry. set up a handler that pipes to sentry.
# example
#  {
#    "handlers": {
#      "sentry": {
#        "type": "pipe",
#        "command": "/path/to/ruby /etc/sensu/handlers/sentry.rb <dsn>",
#        "severities": [
#          "ok",
#          "warning",
#          "critical",
#          "unknown"
#        ]
#      }
#    }
#  }
# disclaimer.. I used snippets from lots of peoples code to make it work..
# including:
# Clark Dave
# (http://clarkdave.net/2014/01/tracking-errors-with-logstash-and-sentry/)
# and of course the sensu documentation....
# Pieced together by: Josh Zitting (jzjoshzitting@gmail.com)

require 'rubygems'
require 'json'
require 'time'
require 'net/https'
require 'uri'

# Read event data
event = JSON.parse(STDIN.read, symbolize_names: true)

# set up the URL and URI
dsn = %r{(.+\/\/)(.+):(.+)@(.+)\/(\d+)}.match("#{ARGV[0]}")
@proto = dsn[1]
@key = dsn[2]
@secret = dsn[3]
@address = dsn[4]
@project_id = dsn[5]
@url = "#{@proto}#{@address}/api/#{@project_id}/store/"
@uri = URI.parse(@url)
@client = Net::HTTP.new(@uri.host, @uri.port)
@client.use_ssl = @proto[0, 5] == 'https' ? true : false
@client.verify_mode = OpenSSL::SSL::VERIFY_NONE

# set the sentry level based off of sensus status
if event[:check][:status] == 0
  level = 'info'
elsif event[:check][:status] == 1
  level = 'warning'
elsif event[:check][:status] == 2
  level = 'fatal'
elsif event[:check][:status] == 3
  level = 'error'
end

# make a time stamp for sentry
tstamp = Time.now.utc.iso8601

# create the header
auth_header = 'Sentry sentry_version=5,' \
'sentry_client=raven-ruby/1.0,' \
"sentry_timestamp=#{event[:client][:timestamp]}," \
"sentry_key=#{@key}, sentry_client=raven-ruby/1.0," \
"sentry_secret=#{@secret}"

# create the event_id
event_id = "#{event[:client][:name]}-#{event[:client][:timestamp]}"

# create the json packet
packet = {
  event_id: event_id,
  culprit: event[:client][:name] + ': ' + event[:check][:name],
  timestamp: tstamp[0..-2],
  message: 'OUTPUT: ' + event[:client][:name] + ': ' + event[:check][:output],
  level: level,
  server_name: event[:client][:name]
}
packet[:platform] = 'sensu'
packet[:logger] = 'sensu'

# send the data to sentry
request = Net::HTTP::Post.new(@uri.path)
begin
  request.body = packet.to_json
  request.add_field('X-Sentry-Auth', auth_header)
  @client.request(request)
end
