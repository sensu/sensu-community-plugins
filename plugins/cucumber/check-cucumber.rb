#! /usr/bin/env ruby
#
#   check-cucumber
#
# DESCRIPTION:
#   A check that executes Cucumber tests
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: <?>
#
# USAGE:
#   #YELLOW
#
# NOTES:
#
# LICENSE:
#   Copyright 2014 Simon Dean <simon@simondean.org>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'sensu-plugin/check/cli'
require 'optparse'
require 'timeout'
require 'json'
require 'yaml'
require 'socket'
require 'English'

class CheckCucumber < Sensu::Plugin::Check::CLI
  OK = 0
  WARNING = 1
  CRITICAL = 2
  UNKNOWN = 3

  INFINITE_TIMEOUT = 0

  option :name,
         description: 'Name to use in sensu events',
         short: '-n NAME',
         long: '--name NAME'

  option :handler,
         description: 'Handler to use for sensu events',
         short: '-h HANDLER',
         long: '--handler HANDLER'

  option :metric_handler,
         description: 'Handler to use for metric events',
         short: '-m HANDLER',
         long: '--metric-handler HANDLER'

  option :metric_prefix,
         description: 'Metric prefix to use with metric paths in sensu events',
         short: '-p METRIC_PREFIX',
         long: '--metric-prefix METRIC_PREFIX'

  option :command,
         description: 'Cucumber command line, including arguments',
         short: '-c COMMAND',
         long: '--command COMMAND'

  option :working_dir,
         description: 'Working directory to use with Cucumber',
         short: '-w WORKING_DIR',
         long: '--working-dir WORKING_DIR'

  option :timeout,
         description: 'Amount of seconds to wait for Cucumber to wait before killing the Cucumber process',
         short: '-t TIMEOUT',
         long: '--timeout TIMEOUT'

  option :env,
         description: 'Environment variable to pass to Cucumber. Can be specified more than once to set multiple environment variables',
         short: '-n NAME=VALUE',
         long: '--env NAME=VALUE'

  option :event_data,
         description: 'Used to add custom data to the sensu events that are raised.  Can be specified more than once to set multiple data items',
         short: '-d NAME=VALUE',
         long: '--event-data NAME=VALUE'

  option :attachments,
         description: 'Specifies whether Cucumber attachments should be included in sensu events. ' \
             'Cucumber attachments can be multi-megabyte if they include screenshots',
         short: '-a BOOLEAN',
         long: '--attachments BOOLEAN'

  option :debug,
         description: 'Print debug information',
         long: '--debug',
         boolean: true

  def parse_options(argv)
    env = {}
    event_data = {}

    process_env_option = lambda do |config_value|
      name, value = config_value.split('=', 2)
      env[name] = value
      env
    end

    process_event_data_option = lambda do |config_value|
      name, value = config_value.split('=', 2)
      event_data[name] = value
      event_data
    end

    options[:env][:proc] = process_env_option
    options[:event_data][:proc] = process_event_data_option

    super(argv)
  end

  def run
    return unless config_is_valid?

    result = nil

    begin
      result = execute_cucumber(config[:env], config[:command], config[:working_dir], config[:timeout])
    rescue Timeout::Error
      unknown_error "Cucumber exceeded the timeout of #{config[:timeout]} seconds"
      return
    end

    puts "Results: #{result[:results]}" if config[:debug]
    puts "Exit status: #{result[:exit_status]}" if config[:debug]

    unless [0, 1].include? result[:exit_status]
      unknown_error "Cucumber returned exit code #{result[:exit_status]}"
      return
    end

    results = JSON.parse(result[:results], symbolize_names: true)

    outcome = :ok
    scenario_count = 0
    statuses = [:passed, :failed, :pending, :undefined]
    status_counts = {}
    statuses.each { |scenario_status| status_counts[scenario_status] = 0 }
    sensu_events = []
    utc_timestamp = Time.now.getutc.to_i

    results.each do |feature|
      # #YELLOW
      Array(feature[:elements]).each do |element| # rubocop:disable Style/Next
        if element[:type] == 'scenario'
          event_name = "#{config[:name]}.#{generate_name_from_scenario(feature, element)}"
          scenario_status = get_scenario_status(element)

          sensu_events << generate_sensu_event(event_name, feature, element, scenario_status)

          metrics = generate_metrics_from_scenario(feature, element, scenario_status, utc_timestamp)

          unless metrics.nil?
            sensu_events << generate_metric_event(event_name, metrics)
          end

          scenario_count += 1
          status_counts[scenario_status] += 1
        end
      end
    end

    puts "Sensu events: #{JSON.pretty_generate(sensu_events)}" if config[:debug]

    errors = raise_sensu_events(sensu_events)

    if errors.length > 0
      outcome = :unknown
    elsif scenario_count == 0
      outcome = :warning
    end

    data = {
      'status' => outcome.to_s,
      'scenarios' => scenario_count
    }

    statuses.each do |status|
      data[status.to_s] = status_counts[status] if status_counts[status] > 0
    end

    data['errors'] = errors if errors.length > 0

    data = dump_yaml(data)

    case outcome
    when :ok
      ok data
    when :warning
      warning data
    when :unknown
      unknown data
    end
  end

  def config_is_valid?
    if config[:name].nil?
      unknown_error 'No name specified'
      return false
    end

    if config[:handler].nil?
      unknown_error 'No handler specified'
      return false
    end

    if config[:metric_handler].nil?
      unknown_error 'No metric handler specified'
      return false
    end

    if config[:metric_prefix].nil?
      unknown_error 'No metric prefix specified'
      return false
    end

    if config[:command].nil?
      unknown_error 'No cucumber command line specified'
      return false
    end

    if config[:working_dir].nil?
      unknown_error 'No working directory specified'
      return false
    end

    config[:timeout] ||= INFINITE_TIMEOUT
    config[:timeout] = Float(config[:timeout]) unless config[:timeout].nil?
    config[:env] ||= {}
    config[:event_data] ||= {}

    config[:attachments] = 'true' if config[:attachments].nil?

    case config[:attachments]
    when 'true'
      config[:attachments] = true
    when 'false'
      config[:attachments] = false
    else
      unknown_error 'Attachments argument is not a valid boolean'
      return false
    end

    true
  end

  def remove_attachments_from_scenario(scenario)
    Array(scenario[:steps]).each do |step|
      step[:embeddings] = [] if step.key?(:embeddings)
    end
  end

  def generate_name_from_scenario(feature, scenario)
    name = scenario[:id]
    name += ";#{feature[:profile]}" if feature.key? :profile

    name = name.gsub(/\./, '-')
      .gsub(/;/, '.')
      .gsub(/[^a-zA-Z0-9\._-]/, '-')
      .gsub(/^\.+/, '')
      .gsub(/\.+$/, '')
      .gsub(/\.+/, '.')

    parts = []

    name.split('.').each do |part|
      part = part.gsub(/^-+/, '')
        .gsub(/-+$/, '')
        .gsub(/-+/, '-')

      parts << part unless part.length == 0
    end

    name = parts.join('.')
    name
  end

  def raise_sensu_events(sensu_events)
    errors = []

    sensu_events.each do |sensu_event|
      data = escape_unicode_characters_in_json(sensu_event.to_json)

      begin
        send_sensu_event(data)
      rescue StandardError => error
        errors << {
          'message' => "Failed to raise event #{sensu_event[:name]}",
          'error' => {
            'message' => error.message,
            'backtrace' => error.backtrace
          }
        }
      end
    end

    errors
  end

  def generate_metrics_from_scenario(feature, scenario, scenario_status, utc_timestamp)
    metrics = []

    if scenario_status == :passed
      scenario_duration = 0

      if scenario.key?(:steps)
        has_step_durations = false
        scenario_metric_prefix = "#{config[:metric_prefix]}.#{generate_name_from_scenario(feature, scenario)}"

        scenario[:steps].each.with_index do |step, step_index|
          if step.key?(:result) && step[:result].key?(:duration)
            has_step_durations = true
            step_duration = step[:result][:duration]
            step_duration = step_duration
            metrics << "#{scenario_metric_prefix}.step-#{step_index + 1}.duration #{step_duration} #{utc_timestamp}"
            scenario_duration += step_duration
          end
        end

        if has_step_durations
          scenario_metrics = [
            "#{scenario_metric_prefix}.duration #{scenario_duration} #{utc_timestamp}",
            "#{scenario_metric_prefix}.step-count #{scenario[:steps].length} #{utc_timestamp}"
          ]
          metrics.unshift scenario_metrics
        end
      end
    end

    if metrics.length == 0
      metrics = nil
    else
      metrics = metrics.join("\n")
    end

    metrics
  end

  private

  def output(msg)
    puts msg
  end

  def execute_cucumber(env, command, working_dir, timeout)
    results = nil
    pipe = nil

    begin
      begin
        Timeout.timeout(timeout) do
          pipe = IO.popen(env, command, chdir: working_dir, external_encoding: Encoding::UTF_8)
          results = pipe.read
        end
      rescue Timeout::Error
        Process.kill 9, pipe.pid
        raise Timeout::Error, 'Cucumber timed out'
      end
    ensure
      pipe.close unless pipe.nil?
    end

    { results: results, exit_status: $CHILD_STATUS.exitstatus }
  end

  def send_sensu_event(data)
    socket = TCPSocket.new('127.0.0.1', 3030)
    socket.setsockopt(Socket::IPPROTO_TCP, Socket::TCP_NODELAY, 1)

    index = 0
    length = data.length

    while index < length
      bytes_sent = socket.send data[index..-1], 0
      index += bytes_sent
    end

    socket.close
  end

  def generate_sensu_event(event_name, feature, scenario, scenario_status)
    scenario_clone = deep_dup(scenario)
    remove_attachments_from_scenario(scenario_clone) unless config[:attachments]
    feature_clone = deep_dup(feature)
    feature_clone[:elements] = [scenario_clone]
    scenario_results = [feature_clone]

    scenario_output = get_output_for_scenario(scenario, scenario_status)

    scenario_status_code = case scenario_status
                           when :passed
                             OK
                           when :failed
                             CRITICAL
                           when :pending, :undefined
                             WARNING
    end

    sensu_event = {
      name: event_name,
      handlers: [config[:handler]],
      status: scenario_status_code,
      output: scenario_output,
      results: scenario_results
    }

    config[:event_data].each do |key, value|
      if value =~ /^\A-?[0-9]+\z/
        value = Integer(value)
      elsif value =~ /^\A-?[0-9]+\.[0-9]+\z/
        value = Float(value)
      elsif value == 'true'
        value = true
      elsif value == 'false'
        value = false
      end
      sensu_event[key] = value
    end

    sensu_event
  end

  def generate_metric_event(event_name, metrics)
    metric_event = {
      name: "#{event_name}.metrics",
      type: 'metric',
      handlers: [config[:metric_handler]],
      output: metrics,
      status: 0
    }

    metric_event
  end

  def get_scenario_status(scenario)
    scenario_status = :passed

    # #YELLOW
    Array(scenario[:steps]).each do |step| # rubocop:disable Style/Next
      if step.key? :result
        step_status = step[:result][:status]

        if %w(failed pending undefined).include? step_status
          scenario_status = step_status.to_sym
          break
        end
      end
    end

    scenario_status
  end

  def get_output_for_scenario(scenario, scenario_status)
    steps_output = []

    Array(scenario[:steps]).each_with_index do |step, index|
      has_result = step.key?(:result)
      step_status = has_result ? step[:result][:status] : 'UNKNOWN'
      step_output = {
        'step' => "#{step_status.upcase} - #{index + 1} - #{step[:keyword]}#{step[:name]}"
      }

      if has_result && step[:result].key?(:error_message)
        step_output['error'] = step[:result][:error_message]
      end

      steps_output << step_output
    end

    scenario_output = {
      'status' => scenario_status.to_s,
      'steps' => steps_output
    }

    dump_yaml(scenario_output)
  end

  def unknown_error(message)
    data = {
      'status' => 'unknown',
      'errors' => [
        {
          'message' => message
        }
      ]
    }
    unknown dump_yaml(data)
  end

  def deep_dup(obj)
    Marshal.load(Marshal.dump(obj))
  end

  def dump_yaml(data)
    data.to_yaml.gsub(/^---\r?\n/, '')
  end

  def escape_unicode_characters_in_json(json)
    json.unpack('U*').map { |i| i < 128 ? i.chr : "\\u#{i.to_s(16).rjust(4, '0')}" }.join
  end
end
