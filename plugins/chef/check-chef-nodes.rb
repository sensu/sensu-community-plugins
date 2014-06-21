#!/usr/bin/env ruby
#
# Check Chef nodes
# ===
#
# It will report you nodes from you cluster last seen more then some amount of seconds
# Set CRITICAL-TIMESPAN to something interval + splay + <average chef kitchen run time>
# Copyright 2014 SUSE, GmbH <happy-customer@suse.de>
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'chef'

class ChefNodesStatusChecker < Sensu::Plugin::Check::CLI

  option :critical_timespan,
         :description => 'Amount of seconds after which node considered as stuck',
         :short => '-t CRITICAL-TIMESPAN',
         :long => '--timespan CRITICAL-TIMESPAN',
         :default => (600 + 300.0 + 60*3)

  option :chef_server_url,
         :description => 'URL of Chef server',
         :short => '-U CHEF-SERVER-URL',
         :long => '--url CHEF-SERVER-URL'

  option :client_name,
         :description => 'Client name',
         :short => '-C CLIENT-NAME',
         :long => '--client CLIENT-NAME'

  option :key,
         :description => 'Client\'s key',
         :short => '-K CLIENT-KEY',
         :long => '--keys CLIENT-KEY'

  def connection
    @connection ||= chef_api_connection
  end

  def nodes_last_seen
    nodes = connection.get_rest('/nodes')
    nodes.keys.map do |node_name|
      node = connection.get_rest("/nodes/#{node_name}")
      { node_name => (Time.now - Time.at(node.ohai_time)) > config[:critical_timespan].to_i }
    end
  end

  def run

    if any_node_stuck?
      ok 'Chef Server API is ok, all nodes reporting'
    else
      critical "Those nodes cannot be provisioned: #{failed_nodes_names}"
    end

  end

  private

  def chef_api_connection
    chef_server_url      = config[:chef_server_url]
    client_name          = config[:client_name]
    signing_key_filename = config[:key]
    Chef::REST.new(chef_server_url, client_name, signing_key_filename)
  end

  def any_node_stuck?
    nodes_last_seen.map(&:values).flatten.all?{|x| x == false}
  end

  def failed_nodes_names
    all_failed_tuples = nodes_last_seen.select{|node_set| node_set.values.first == true}
    all_failed_tuples.map(&:keys).flatten.join(', ')
  end

end
