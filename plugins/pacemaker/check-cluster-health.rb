#! /usr/bin/env ruby
#
#   cjeck-cluster-health
#
# DESCRIPTION:
#   Check pacemaker cluster for offline nodes or failed resources
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: rexml
#
# USAGE:
#   #YELLOW
#
# NOTES:
#
# LICENSE:
#   Copyright (c) 2014, Nathan Williams <nath.e.will@gmail.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'rexml/document'

class CheckClusterHealth < Sensu::Plugin::Check::CLI
  option :warn_offline,
         short: '-o OFFLINE_NODES',
         long: '--warn-offline OFFLINE_NODES',
         description: 'Number of offline nodes to trigger warning',
         default: 1

  option :critical_offline,
         short: '-O OFFLINE_NODES',
         long: '--critical-offline OFFLINE_NODES',
         description: 'Number of offline nodes to trigger critical',
         default: 1

  option :warn_failed,
         short: '-f FAILED_RESOURCES',
         long: '--warn-failed FAILED_RESOURCES',
         description: 'Number of failed resources to trigger warning',
         default: 1

  option :critical_failed,
         short: '-F FAILED_RESOURCES',
         long: '--critical-failed FAILED_RESOURCES',
         description: 'Number of failed resources to trigger critical',
         default: 1

  def run
    cluster_state = REXML::Document.new(cluster_xml)

    nodes = cluster_state.elements.to_a('crm_mon/nodes/node').length
    resources = cluster_state.elements.to_a('crm_mon/nodes/node/resource').length

    offline_nodes = []
    failed_resources = []

    cluster_state.elements.each('crm_mon/nodes/node') do |node|
      if node.attributes['expected_up'] == 'true' && node.attributes['online'] == 'false'
        offline_nodes << node.attributes['name']
      end

      node.elements.each('resource') do |resource|
        if resource.attributes['failed'] == 'true'
          failed_resources << resource.attributes['id']
        end
      end
    end

    critical "#{offline_nodes.length}/#{nodes} node(s) offline!" if offline_nodes.length >= config[:critical_offline]
    critical "#{failed_resources.length}/#{resources} resources failed!" if failed_resources.length >= config[:critical_failed]

    warn "#{offline_nodes.length} node(s) offline!" if offline_nodes.length >= config[:warn_offline]
    warn "#{failed_resources.length}/#{resources} resources failed!" if failed_resources.length >= config[:warn_failed]

    ok "#{offline_nodes.length}/#{nodes} nodes offline, #{failed_resources.length}/#{resources} resources failed."
  end

  def cluster_xml
    `crm_mon -Xn`
  end
end
