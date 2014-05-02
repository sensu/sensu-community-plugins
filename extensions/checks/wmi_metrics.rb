# WMI Metrics
# ===
#
# Collects a variety of system metrics every 10 seconds (by default).
# Expects a "graphite" handler on the Sensu server, eg:
#
# "graphite": {
#   "type": "tcp",
#   "socket": {
#     "host": "graphite.hw-ops.com",
#     "port": 2003
#   },
#   "mutator": "only_check_output"
# }
#
# Copyright 2014 Heavy Water Operations, LLC.
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'ruby-wmi'

module Sensu
  module Extension
    class WMIMetrics < Check
      def name
        'wmi_metrics'
      end

      def description
        'collects system metrics, using wmi and the graphite plain-text format'
      end

      def definition
        {
          :type => 'metric',
          :name => name,
          :interval => options[:interval],
          :standalone => true,
          :handler => options[:handler]
        }
      end

      def post_init
        @metrics = []
      end

      def run
        memory_metrics do
          disk_metrics do
            cpu_metrics do
              network_interface_metrics do
                yield flush_metrics, 0
              end
            end
          end
        end
      end

      private

      def options
        return @options if @options
        @options = {
          :interval => 10,
          :handler => 'graphite',
          :add_client_prefix => true,
          :path_prefix => 'WMI'
        }
        if settings[:system_profile].is_a?(Hash)
          @options.merge!(settings[:system_profile])
        end
        @options
      end

      def flush_metrics
        metrics = @metrics.join("\n") + "\n"
        @metrics = []
        metrics
      end

      def add_metric(*args)
        value = args.pop
        path = []
        if options[:add_client_prefix]
          path << settings[:client][:name]
        end
        path << options[:path_prefix]
        path = (path + args).join('.')
        @metrics << [path, value, Time.now.to_i].join(' ')
      end

      def formatted_perf_data(provider, filter = :first)
        full_provider = 'Win32_PerfFormattedData_' + provider
        query = Proc.new do
          begin
            ::WMI.const_get(full_provider).find(filter)
          rescue => error
            @logger.error('wmi query error', {
              :error => error.to_s
            })
            nil
          end
        end
        EM.defer(query, Proc.new { |data| yield data })
      end

      def memory_metrics
        formatted_perf_data('PerfOS_Memory') do |data|
          unless data.nil?
            %w[
              AvailableBytes
              CacheBytes
              CommittedBytes
            ].each do |point|
              add_metric('Memory', point, data.send(point.to_sym))
            end
          end
          yield
        end
      end

      def disk_metrics
        formatted_perf_data('PerfDisk_LogicalDisk', :all) do |disks|
          unless disks.nil?
            disks.each do |data|
              %w[
                AvgDiskQueueLength
                FreeMegabytes
                PercentDiskTime
                PercentFreeSpace
              ].each do |point|
                disk_name = data.Name.gsub(/[^0-9a-z]/i, '')
                add_metric('Disk', disk_name, point, data.send(point.to_sym))
              end
            end
          end
          yield
        end
      end

      def cpu_metrics
        formatted_perf_data('PerfOS_Processor', :all) do |processors|
          unless processors.nil?
            processors.each do |data|
              %w[
                InterruptsPerSec
                PercentIdleTime
                PercentInterruptTime
                PercentPrivilegedTime
                PercentProcessorTime
                PercentUserTime
              ].each do |point|
                cpu_name = data.Name.gsub(/[^0-9a-z]/i, '')
                add_metric('CPU', cpu_name, point, data.send(point.to_sym))
              end
            end
          end
          yield
        end
      end

      def network_interface_metrics
        formatted_perf_data('Tcpip_NetworkInterface', :all) do |interfaces|
          unless interfaces.nil?
            interfaces.each do |data|
              %w[
                BytesReceivedPerSec
                BytesSentPerSec
                BytesTotalPerSec
                OutputQueueLength
                PacketsOutboundDiscarded
                PacketsOutboundErrors
                PacketsPerSec
                PacketsReceivedDiscarded
                PacketsReceivedErrors
                PacketsReceivedPerSec
                PacketsSentPerSec
              ].each do |point|
                interface_name = data.Name.gsub(/[^0-9a-z]/i, '')
                add_metric('Interface', interface_name, point, data.send(point.to_sym))
              end
            end
          end
          yield
        end
      end
    end
  end
end
