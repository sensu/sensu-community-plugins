#!/usr/bin/env ruby
# Sensu Elasticsearch Metrics Handler

require 'sensu-handler'
require 'net/http'
require 'timeout'
require 'digest/md5'
require 'date'

class ElasticsearchMetrics < Sensu::Handler
  def host
    settings['elasticsearch']['host'] || 'localhost'
  end

  def port
    settings['elasticsearch']['port'] || 9200
  end

  def time_out
    settings['elasticsearch']['timeout'] || 5
  end

  def es_index
    "#{settings['elasticsearch']['index']}-#{DateTime.now.strftime '%Y.%m.%d'}"
  end

  def es_type
    @event['check']['name']
  end

  def es_id
    rdm = ((0..9).to_a + ('a'..'z').to_a + ('A'..'Z').to_a).sample(3).join
    Digest::MD5.new.update rdm
  end

  def time_stamp
    DateTime.now.to_s
  end

  def handle
    @event['check']['output'].split("\n").each do |line|
      v = line.split "\t"
      metrics = {
        :@timestamp => time_stamp,
        client: @event['client']['name'],
        check_name: @event['check']['name'],
        status: @event['check']['status'],
        address: @event['client']['address'],
        command: @event['check']['command'],
        occurrences: @event['occurrences'],
        key: v[0],
        value: v[1]
      }

      begin
        timeout(time_out) do
          uri = URI "http://#{host}:#{port}/#{es_index}/#{es_type}/#{es_id}"
          http = Net::HTTP.new uri.host, uri.port
          request = Net::HTTP::Post.new uri.path, 'content-type' => 'application/json; charset=utf-8'
          request.body = JSON.dump metrics

          response = http.request request
          if response.code =~ /20[01]/
            puts "request metrics #=> #{metrics}"
            puts "response body #=> #{response.body}"
            puts 'elasticsearch post ok.'
          else
            puts "request metrics #=> #{metrics}"
            puts "response body #=> #{response.body}"
            puts "elasticsearch post failure. status error code #=> #{response.code}"
          end
        end
      rescue Timeout::Error
        puts 'elasticsearch timeout error.'
      end
    end
  end
end
