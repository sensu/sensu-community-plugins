# System Profile (metrics)
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

require 'sys/filesystem'
include Sys

module Sensu
  module Extension
    class SystemProfile < Check
      def name
        'system_profile'
      end

      def description
        'collects system metrics, using the graphite plain-text format'
      end

      def definition
        {
          type: 'metric',
          name: name,
          interval: options[:interval],
          standalone: true,
          handler: options[:handler]
        }
      end

      def post_init
        @metrics = []
      end

      def run
        proc_stat_metrics do
          proc_loadavg_metrics do
            proc_net_dev_metrics do
              proc_meminfo_metrics do
                disk_usage do
                  yield flush_metrics, 0
                end
              end
            end
          end
        end
      end

      private

      def options
        return @options if @options
        @options = {
          interval: 10,
          handler: 'graphite',
          add_metric_prefix: true,
          metric_prefix: 'os',
          add_client_prefix: true,
          path_prefix: 'system',
          prefix_at_start: 0
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
        path << options[:path_prefix] if options[:prefix_at_start]
        path << settings[:client][:name] if options[:add_client_prefix]
        path << options[:path_prefix] unless options[:prefix_at_start]
        path << options[:metric_prefix] if options[:add_metric_prefix]
        path = (path + args).join('.')
        @metrics << [path, value, Time.now.to_i].join(' ')
      end

      def read_file(file_path, chunk_size = nil)
        content = ''
        File.open(file_path, 'r') do |file|
          read_chunk = proc do
            content << file.read(chunk_size)
            # #YELLOW
            unless file.eof? # rubocop:disable UnlessElse
              EM.next_tick(read_chunk)
            else
              yield content
            end
          end
          read_chunk.call
        end
      end

      def parse_proc_stat
        sample = {}
        cpu_metrics = %w(user nice system idle iowait irq softirq steal guest)
        misc_metrics = %w(ctxt processes procs_running procs_blocked btime intr)
        read_file('/proc/stat') do |proc_stat|
          proc_stat.each_line do |line|
            next if line.empty?
            data = line.split(/\s+/)
            key = data.shift
            values = data.map(&:to_i)
            if key =~ /cpu([0-9]+|)/
              sample[key] = Hash[cpu_metrics.zip(values)]
              sample[key]['total'] = values.inject(:+)
            elsif misc_metrics.include?(key)
              sample[key] = values.last
            end
          end
          yield sample
        end
      end

      def proc_stat_metrics
        parse_proc_stat do |previous|
          EM::Timer.new(1) do
            parse_proc_stat do |sample|
              sample.each do |key, data|
                if key =~ /^cpu/
                  cpu_total_diff = (data.delete('total') - previous[key]['total']) + 1
                  data.each do |metric, value|
                    next if value.nil?
                    diff = value - previous[key][metric]
                    used = sprintf('%.02f', (diff / cpu_total_diff.to_f) * 100)
                    add_metric(key, metric, used)
                  end
                else
                  add_metric(key, data)
                end
              end
              yield
            end
          end
        end
      end

      def disk_usage
        read_file('/etc/mtab') do |etc_mtab|
          etc_mtab.each_line do |line|
            next if line.strip.eql? ''
            next if line.start_with?('#')
            volume = line.split(/\s+/)
            path = volume[1].to_s
            type = volume[2].to_s
            next if ["autofs", "binfmt_misc", "cgroup", "configfs", "debugfs", "devpts", "devtmpfs", "hugetlbfs", "mqueue", "nfsd", "proc", "pstore", "rootfs", "rpc_pipefs", "securityfs", "selinuxfs", "sysfs", "tmpfs"].include?(type)
            stat = Filesystem.stat(path)
            used = stat.percent_used
            if path.eql? '/'
              path = 'root'
            end
            path.gsub!('/', '_')
            add_metric('disk_usage', path, used)
          end
          yield
        end
      end

      def proc_loadavg_metrics
        read_file('/proc/loadavg') do |proc_loadavg|
          values = proc_loadavg.split(/\s+/).take(3).map(&:to_f)
          add_metric('load_avg', '1_min', values[0])
          add_metric('load_avg', '5_min', values[1])
          add_metric('load_avg', '15_min', values[2])
          yield
        end
      end

      def proc_net_dev_metrics
        dev_metrics = %w(rxBytes
                         rxPackets
                         rxErrors
                         rxDrops
                         rxFifo
                         rxFrame
                         rxCompressed
                         rxMulticast
                         txBytes
                         txPackets
                         txErrors
                         txDrops
                         txFifo
                         txColls
                         txCarrier
                         txCompressed)
        read_file('/proc/net/dev') do |proc_net_dev|
          proc_net_dev.each_line do |line|
            interface, data = line.scan(/^\s*([^:]+):\s*(.*)$/).first
            next unless interface
            values = data.split(/\s+/).map(&:to_i)
            Hash[dev_metrics.zip(values)].each do |key, value|
              add_metric('net', interface, key.downcase, value)
            end
          end
          yield
        end
      end

      def proc_meminfo_metrics
        read_file('/proc/meminfo') do |proc_meminfo|
          mem_abs = {}
          swap_abs = {}
          proc_meminfo.each_line do |line|
            next if line.strip.empty?
            root, data = line.split(':')
            values = data.strip.split(/\s+/).map(&:to_i)
            case root
            when /Mem\w+/, 'Buffers', 'Cached', 'Active', 'Committed_AS'
              key = root.gsub(/^Mem/, '').downcase
              mem_abs[key] = values.first
            when /Swap\w+/
              key = root.gsub(/^Swap/, '').downcase
              swap_abs[key] = values.first
            end
          end
          mem_abs['used'] = mem_abs['total'] - mem_abs['free']
          mem_abs['usedWOBuffersCaches'] = mem_abs['used'] - mem_abs['buffers'] - mem_abs['cached']
          mem_abs['freeWOBuffersCaches'] = mem_abs['free'] + mem_abs['buffers'] + mem_abs['cached']
          mem_rel = {}
          mem_abs.each do |mname, mval|
            if mname != 'total'
              if mem_abs['total']  == 0
                mem_abs['total'] = 1
              end
              mem_rel[mname] = 100 * mem_abs[mname] / mem_abs['total']
            end
          end
          mem_rel['total'] = 100
          swap_rel = {}
          swap_abs.each do |swname, swval|
            if swname != 'total'
              if swap_abs['total'] == 0
                swap_abs['total'] = 1
              end
              swap_rel[swname] = 100 * swap_abs[swname] / swap_abs['total']
            end
          end
          swap_rel['total'] = 100
          mem_rel.each do |mname, mval|
            add_metric('memory', mname, mval)
          end
          swap_rel.each do |swname, swval|
            add_metric('swap', swname, swval)
          end
          yield
        end
      end
    end
  end
end
