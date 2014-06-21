#!/usr/bin/env ruby

# Author: AJ Bourg <aj@ajbourg.com>

# Check to ensure data gets posted and is retrievable by graphite.
# We post to each server in config[:relays] then sleep config[:sleep]
# seconds then check each of config[:graphites] to see if the data made it
# to each one. OK if all servers have the data we expected, WARN if
# config[:warning] or fewer have it. CRITICAL if config[:critical]
# or fewer have it. config[:check_id] allows you to have many of these
# checks running in different places without any conflicts. Customize it
# if you are going to run this check from multiple servers. Otherwise
# it defaults to default. (can be a descriptive string, used as a graphite key)
#
# This check is most useful when you have a cluster of carbon-relays configured
# with REPLICATION_FACTOR > 1 and more than one graphite server those
# carbon-relays are configured to post to. This check ensures that replication
# is actually happening in a timely manner.

# How it works: We generate a large random number for each of these servers
# Then we post that number to each server via a key in the form of:
# checks.graphite.check_id.replication.your_graphite_server.ip It's safe
# to throw this data away quickly. A day retention ought to be more
# than enough for anybody.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'timeout'
require 'socket'
require 'rest-client'
require 'json'
require 'resolv'
require 'ipaddress'

class CheckGraphiteReplication < Sensu::Plugin::Check::CLI
  option :relays,
    :short => '-r RELAYS',
    :long => '--relays RELAYS',
    :description => 'Comma separated list of carbon relay servers to post to.',
    :required => true
  option :servers,
    :short => '-g SERVERS',
    :long => '--graphite SERVERS',
    :description => 'Comma separated list of all graphite servers to check.',
    :required => true
  option :sleep,
    :short => '-s SECONDS',
    :long => '--sleep SECONDS',
    :description => 'Time to sleep between submitting and checking for value.',
    :default => 30,
    :proc => proc { |a| a.to_i }
  option :timeout,
    :short => '-t TIMEOUT',
    :long => '--timeout TIMEOUT',
    :description => 'Timeout limit for posting to the relay.',
    :default => 5,
    :proc => proc { |a| a.to_i }
  option :port,
    :short => '-p PORT',
    :long => '--port PORT',
    :description => 'Port to post to carbon-relay on.',
    :default => 2003,
    :proc => proc { |a| a.to_i }
  option :critical,
    :short => '-c COUNT',
    :long => '--critical COUNT',
    :description => 'Number of servers missing our test data to be critical.',
    :default => 2,
    :proc => proc { |a| a.to_i }
  option :warning,
    :short => '-w COUNT',
    :long => '--warning COUNT',
    :description => 'Number of servers missing our test data to be warning.',
    :default => 1,
    :proc => proc { |a| a.to_i }
  option :check_id,
    :short => '-i ID',
    :long => '--check-id ID',
    :description => 'Check ID to identify this check.',
    :default => "default"
  option :verbose,
    :short => '-v',
    :long => '--verbose',
    :description => 'Verbose.',
    :default => false,
    :boolean => true

  def run
    messages = []
    servers = config[:servers].split(',')
    relay_ips = find_relay_ips(config[:relays].split(','))

    check_id = graphite_key(config[:check_id])

    relay_ips.each do |server_name, ips|
      ips.each do |ip|
        messages << post_message(server_name, ip, check_id)
      end
    end

    puts "Sleeping for #{config[:sleep]}." if config[:verbose]
    sleep(config[:sleep])

    fail_count = 0
    # on every server, check to see if all our data replicated
    servers.each do |server|
      messages.each_with_index do |c|
        unless check_for_message(server, c['key'], c['value'])
          puts "#{c['relay']} (#{c['ip']}) didn't post to #{server}"
          fail_count += 1
        end
      end
    end

    if fail_count >= config[:critical]
      critical "Missing data points. #{fail_count} lookups failed."
    elsif fail_count >= config[:warning]
      warning "Missing data points. #{fail_count} lookups failed."
    end

    success_count = (messages.length * servers.length) - fail_count
    ok "#{fail_count} failed checks. #{success_count} successful checks."
  end

  def find_relay_ips(relays)
    # we may have gotten an IPAddress or a DNS hostname or a mix, so let's try

    relay_ips = {}

    time_out("resolving dns") do
      relays.each do |r|
        if IPAddress.valid? r
          relay_ips[r] = [r]
        else
          relay_ips[r] = Resolv.getaddresses(r)
        end
      end
    end

    relay_ips
  end

  def post_message(server_name, ip, check_id)
    server_key = graphite_key(server_name)

    number = rand(10000)
    time = Time.now.to_i

    ip_key = graphite_key(ip)
    key = "checks.graphite.#{check_id}.replication.#{server_key}.#{ip_key}"

    time_out("posting data to #{ip}") do
      t = TCPSocket.new(ip, config[:port])
      t.puts("#{key} #{number} #{time}")
      t.close
    end

    if config[:verbose]
      puts "Posted #{key} to #{server_name} with #{number} on IP #{ip}."
    end

    { "relay" => server_name, "ip" => ip, "key" => key, "value" => number }
  end

  # checks to see if a value landed on a graphite server
  def check_for_message(server, key, value)
    url = "http://#{server}/render?format=json&target=#{key}&from=-10minutes"

    puts "Checking URL #{url}" if config[:verbose]
    graphite_data = nil

    begin
      time_out("querying graphite api on #{server}") do
        graphite_data = RestClient.get url
        graphite_data = JSON.parse(graphite_data)
      end
    rescue RestClient::Exception, JSON::ParserError => e
      critical "Unexpected error getting data from #{server}: #{e.to_s}"
    end

    success = false

    # we get all the data points for the last 10 minutes, so see if our value
    # appeared in any of them
    graphite_data[0]['datapoints'].each do |v|
      success = true if v[0] == value
    end

    success
  end

  def graphite_key(key)
    key.gsub(',', '_').gsub(' ', '_').gsub('.', '_').gsub('-', '_')
  end

  def time_out(activity, &block)
    begin
      Timeout.timeout(config[:timeout]) do
        yield block
      end
    rescue Timeout::Error
      critical "Timed out while #{activity}"
    end
  end

end
