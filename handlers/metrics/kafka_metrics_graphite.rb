#!/usr/bin/env ruby
#
# Copyright 2015 Autumn Wang <shoujinwang@gmail.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.
#
# This is the handler to send sensu metrics to kafka message queue,
# which will be consumed by graphite. 
# So the message format is a graphite metrics format likes : "key value timestamp"
#
# The configuration is in kafka-metrics-graphite.json.
#   The servers like "server1:port1,server2:port2,....."
#   The topic is the kafka topic which this handler will send the messages to.
#
#


require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
require 'timeout'
require 'poseidon'

class SensuToKafka < Sensu::Handler
  def handle
    kafka_servers = settings['kafka']['servers'].split(',').map(&:strip)
    kafka_topic   = settings['kafka']['topic']
      
    producer = Poseidon::Producer.new(kafka_servers, "sensu_kafka_handler")
    
    now = Time.now.to_i
    
    @event['check']['output'].each_line do |metric|
      m = metric.split
      next unless m.count == 3
      key = m[0]
      next unless key
      value = m[1].to_f
      
      begin
        timeout(3) do
          message = Poseidon::MessageToSend.new(kafka_topic, "#{key} #{value} #{now}")
          reponse = producer.send_messages([message])
          if reponse == true
            puts "kafka-metrics-graphite post ok. message : #{key} #{value} #{now}"
          end
        end
      rescue Timeout::Error
        puts 'kafka-metrics -- timed out while sending metrics'
      rescue => error
        puts "kafka-metrics -- failed to send metrics: #{error}"
      end
    end
  end
end
