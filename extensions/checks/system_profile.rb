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
          :type => 'metric',
          :name => name,
          :interval => options[:interval],
          :standalone => true,
          :handler => 'graphite'
        }
      end

      def post_init
        @metrics = []
      end

      def run
        proc_stat_metrics do
          proc_loadavg_metrics do
            yield flush_metrics, 0
          end
        end
      end

      private

      def options
        return @options if @options
        @options = {
          :interval => 10,
          :file_chunk_size => 1024,
          :add_client_prefix => true,
          :path_prefix => 'system'
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

      def read_file(file_path)
        content = ''
        File.open(file_path, 'r') do |file|
          read_chunk = Proc.new do
            content << file.read(options[:file_chunk_size])
            unless file.eof?
              EM::next_tick(read_chunk)
            else
              yield content
            end
          end
          read_chunk.call
        end
      end

      def parse_proc_stat
        sample = {}
        cpu_metrics = ['user', 'nice', 'system', 'idle', 'iowait', 'irq', 'softirq', 'steal', 'guest']
        misc_metrics = ['ctxt', 'processes', 'procs_running', 'procs_blocked', 'btime', 'intr']
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

      def proc_loadavg_metrics
        read_file('/proc/loadavg') do |proc_loadavg|
          values = proc_loadavg.split(/\s+/).take(3).map(&:to_f)
          add_metric('load_avg', '1_min', values[0])
          add_metric('load_avg', '5_min', values[1])
          add_metric('load_avg', '15_min', values[2])
          yield
        end
      end
    end
  end
end
