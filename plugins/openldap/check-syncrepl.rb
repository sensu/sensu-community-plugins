#!/usr/bin/env ruby
#
# Checks the status of OpenLDAP syncrepl
# ===
#
# DESCRIPTION:
#   This plugin checks OpenLDAP nodes to veryfiy syncrepl is working
#   This currently only works with TLS and binding as a user
#
# PLATFORMS:
#   all
#
# DEPENDENCIES:
#   sensu-plugin >= 1.5 Ruby gem
#   net-ldap >= 0.3.1 Ruby gem
#
# Copyright (c) 2014, Justin Lambert <jlambert@letsevenup.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'net/ldap'

class CheckSyncrepl < Sensu::Plugin::Check::CLI

  option :hosts,
    :short        => '-h HOSTS',
    :long         => '--hosts HOSTS',
    :description  => 'Comma seperated list of hosts to compare',
    :required     => true,
    :proc         => proc { |hosts| hosts.split(',') }

  option :port,
    :short        => '-t PORT',
    :long         => '--port PORT',
    :description  => 'Port to connect to OpenLDAP on',
    :default      => 636,
    :proc         => proc { |i| i.to_i }

  option :base,
    :short        => '-b BASE',
    :long         => '--base BASE',
    :description  => 'Base to fetch the ContextCSN for',
    :required     => true

  option :user,
    :short        => '-u USER',
    :long         => '--user USER',
    :description  => 'User to bind as',
    :required     => true

  option :password,
    :short        => '-p PASSWORD',
    :long         => '--password PASSWORD',
    :description  => 'Password used to bind',
    :required     => true

  option :retries,
    :short        => '-r RETRIES',
    :long         => '--retries RETRIES',
    :description  => 'Number of times to retry (useful for environments with larger number of writes)',
    :default      => 0,
    :proc         => proc { |i| i.to_i }

  def get_csns(host)
    ldap = Net::LDAP.new :host => host,
      :port => config[:port],
      :encryption => {
        :method => :simple_tls
      },
      :auth => {
        :method => :simple,
        :username => config[:user],
        :password => config[:password]
      }

    begin
      if ldap.bind
        ldap.search(:base => config[:base], :attributes => ['contextCSN'], :return_result => true, :scope => Net::LDAP::SearchScope_BaseObject) do |entry|
          return entry['contextcsn']
        end
      else
        critical "Cannot connect to #{host}:#{config[:port]} as #{config[:user]}"
      end
    end
  rescue
    critical "Cannot connect to #{host}:#{config[:port]} as #{config[:user]}"
  end

  def run
    unknown "Cannot compare 1 node (to anything else)." if config[:hosts].length == 1

    (config[:retries] + 1).times do
      # Build a list of contextCSNs from each host
      csns = {}
      config[:hosts].each do |host|
        csns[host] = get_csns host
      end

      # Compare all combinations of nodes
      @differences = []
      combinations = csns.keys.combination(2).to_a
      combinations.each do |hosts|
        @differences << hosts if (csns[hosts[0]] - csns[hosts[1]]).length > 0
      end

      # If everything is OK, no need to retry
      ok "All nodes are in sync" if @differences.length == 0
    end

    # Hit max retries, report latest differences
    message = "ContextCSNs differe between: "

    joined = []
    @differences.each do |different|
      joined << different.sort.join(' and ')
    end
    message += joined.sort.join(', ')
    critical message
  end
end
