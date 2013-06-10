#!/usr/bin/env ruby
#
# Push Apache Solr stats into graphite
# ===
#
# TODO: Flags to narrow down needed stats only
#
# Copyright 2013 Kyle Burckhard <kyle@marketfish.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'rest-client'
require 'json'

class Solr4Graphite < Sensu::Plugin::Metric::CLI::Graphite

  option :host,
         short:       '-h HOST',
         long:        '--host HOST',
         description: 'Solr Host to connect to',
         required:    true

  option :port,
         short:        '-p PORT',
         long:         '--port PORT',
         description:  'Solr Port to connect to',
         proc:         proc { |p| p.to_i },
         required:     true

  option :scheme,
         description:  'Metric naming scheme, text to prepend to metric',
         short:        '-s SCHEME',
         long:         '--scheme SCHEME',
         default:      "#{Socket.gethostname}.solr"

  def get_url_json(url)
    begin
      r = RestClient::Resource.new(url, timeout: 45)
      JSON.parse(r.get)
    rescue Errno::ECONNREFUSED
      warning 'Connection refused'
    rescue RestClient::RequestTimeout
      warning 'Connection timed out'
    rescue RestClient::ResourceNotFound
      warning "404 resource not found - #{url}"
    rescue => e
      warning "RestClient exception: #{e.class} -> #{e.message}"
    end
  end

  def run
    graphite_path = config[:scheme]

     # Process core stats
    core_json = get_url_json "http://#{config[:host]}:#{config[:port]}/solr/admin/cores?stats=true&wt=json"

    output "#{graphite_path}.Status", core_json['responseHeader']['status']
    output "#{graphite_path}.QueryTime", core_json['responseHeader']['QTime']

    # Process system stats
    first_core = core_json['status'].keys.first

    sys_json = get_url_json "http://#{config[:host]}:#{config[:port]}/solr/#{first_core}/admin/system?stats=true&wt=json"
    sys_json['jvm']['memory']['raw'].each do |stat, value|
      output "#{graphite_path}.jvm.memory.#{stat}", value
    end
    output "#{graphite_path}.system.openFileCount", sys_json['system']['openFileDescriptorCount']
    output "#{graphite_path}.system.maxFileCount",  sys_json['system']['maxFileDescriptorCount']

    core_json['status'].keys.each do |core|
      graphite_path = "#{config[:scheme]}.#{core}"
      mbeans_json = get_url_json "http://#{config[:host]}:#{config[:port]}/solr/#{core}/admin/mbeans?stats=true&wt=json"

      output "#{graphite_path}.Status", mbeans_json['responseHeader']['status']
      output "#{graphite_path}.QueryTime", mbeans_json['responseHeader']['QTime']

      mbeans_json['solr-mbeans'] = Hash[*mbeans_json['solr-mbeans']]

      collection  = mbeans_json['solr-mbeans']['CORE']['core']['stats']['collection']
      shard       = mbeans_json['solr-mbeans']['CORE']['core']['stats']['shard']

      graphite_path += ".#{collection}.#{shard}"

      mbeans_json['solr-mbeans']['CORE']['searcher']['stats'].each do |stat, value|
        output "#{graphite_path}.searcher.#{stat}", value if value.kind_of?(Numeric)
      end

      # query handler stats
      {
        '/update'       => 'updates',
        '/query'        => 'queries',
        '/select'       => 'selects',
        '/replication'  => 'replication',
      }.each do |hash_node, graphite_node|
        mbeans_json['solr-mbeans']['QUERYHANDLER'][hash_node]['stats'].each do |stat, value|
          output "#{graphite_path}.queryHandler.#{graphite_node}.#{stat}", value if value.kind_of?(Numeric)
          output "#{graphite_path}.queryHandler.replication.#{stat}", (value.to_f * 1_073_741_824).to_i if value =~ /\d+\.?\d* GB/
        end
      end

      mbeans_json['solr-mbeans']['UPDATEHANDLER']['updateHandler']['stats'].each do |stat, value|
        output "#{graphite_path}.updateHandler.#{stat.gsub(' ', '_')}", value if value.kind_of?(Numeric)
      end

      # cache stats
      {
        'queryResultCache'  => 'queryResults',
        'fieldCache'        => 'fields',
        'documentCache'     => 'documents',
        'fieldValueCache'   => 'fieldValues',
        'filterCache'       => 'filters'
      }.each do |hash_node, graphite_node|
        next unless mbeans_json['solr-mbeans']['CACHE'][hash_node]
        mbeans_json['solr-mbeans']['CACHE'][hash_node]['stats'].each do |stat, value|
          output "#{graphite_path}.cache.#{graphite_node}.#{stat}", value if value.kind_of?(Numeric)
        end
      end
    end

    ok
  end
end
