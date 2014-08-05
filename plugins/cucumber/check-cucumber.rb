#!/usr/bin/env ruby
#
#
# ===
#
# DESCRIPTION:
#   A check that executes Cucumber tests
#
# OUTPUT:
#   plain-text
#
# PLATFORMS:
#   all
#
# DEPENDENCIES:
#   sensu-plugin Ruby gem
#
# Copyright 2014 Simon Dean <simon@simondean.org>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'json'
require 'socket'

class CheckCucumber < Sensu::Plugin::Check::CLI
  OK = 0
  WARNING = 1
  CRITICAL = 2
  UNKNOWN = 3

  option :name,
    :description => "Name to use in sensu events",
    :short => '-n NAME',
    :long => '--name NAME'

  option :handler,
    :description => "Handler to use for sensu events",
    :short => '-h HANDLER',
    :long => '--handler HANDLER'

  option :metric_handler,
    :description => "Handler to use for metric events",
    :short => '-m HANDLER',
    :long => '--metric-handler HANDLER'

  option :metric_prefix,
    :description => "Metric prefix to use with metric paths in sensu events",
    :short => '-p METRIC_PREFIX',
    :long => '--metric-prefix METRIC_PREFIX'

  option :command,
    :description => "Cucumber command line, including arguments",
    :short => '-c COMMAND',
    :long => '--command COMMAND'

  option :working_dir,
    :description => "Working directory to use with Cucumber",
    :short => '-w WORKING_DIR',
    :long => '--working-dir WORKING_DIR'

  option :debug,
    :description => "Print debug information",
    :long => '--debug',
    :boolean => true

  def execute_cucumber
    report = nil

    IO.popen(config[:command], :chdir => config[:working_dir]) do |io|
      report = io.read
    end

    {:report => report, :exit_status => $?.exitstatus}
  end

  def run
    if config[:name].nil?
      unknown 'No name specified'
      return
    end

    if config[:handler].nil?
      unknown 'No handler specified'
      return
    end

    if config[:metric_handler].nil?
      unknown 'No metric handler specified'
      return
    end

    if config[:metric_prefix].nil?
      unknown 'No metric prefix specified'
      return
    end

    if config[:command].nil?
      unknown 'No cucumber command line specified'
      return
    end

    if config[:working_dir].nil?
      unknown 'No working directory specified'
      return
    end

    result = execute_cucumber

    puts "Report: #{result[:report]}" if config[:debug]
    puts "Exit status: #{result[:exit_status]}" if config[:debug]

    unless [0, 1].include? result[:exit_status]
      unknown "Cucumber returned exit code #{result[:exit_status]}"
      return
    end

    report = JSON.parse(result[:report], :symbolize_names => true)

    outcome = OK
    scenario_count = 0
    statuses = [:passed, :failed, :pending, :undefined]
    status_counts = {}
    statuses.each {|scenario_status| status_counts[scenario_status] = 0}
    sensu_events = []
    utc_timestamp = Time.now.getutc.to_i

    report.each do |feature|
      if feature.has_key? :elements
        feature[:elements].each do |element|
          if element[:type] == 'scenario'
            scenario_status = :passed

            if element.has_key? :steps
              element[:steps].each do |step|
                if step.has_key? :result
                  step_status = step[:result][:status]

                  if ['failed', 'pending', 'undefined'].include? step_status
                    scenario_status = step_status.to_sym
                    break
                  end
                end
              end
            end

            feature_clone = deep_dup(feature)
            feature_clone[:elements] = [deep_dup(element)]
            scenario_report = [feature_clone]

            data = {
              :status => scenario_status,
              :report => scenario_report
            }

            event_name = "#{config[:name]}.#{generate_name_from_scenario(element)}"

            sensu_event = {
              :name => event_name,
              :handlers => [config[:handler]],
              :output => data.to_json
            }

            case scenario_status
              when :passed
                sensu_event[:status] = OK
              when :failed
                sensu_event[:status] = CRITICAL
              when :pending, :undefined
                sensu_event[:status] = WARNING
            end

            sensu_events << sensu_event

            metrics = generate_metrics_from_scenario(element, scenario_status, utc_timestamp)

            unless metrics.nil?
              metric_event = {
                :name => "#{event_name}.metrics",
                :type => 'metric',
                :handlers => [config[:metric_handler]],
                :output => metrics,
                :status => 0
              }
              sensu_events << metric_event
            end

            scenario_count += 1
            status_counts[scenario_status] += 1
          end
        end
      end
    end

    puts "Sensu events: #{JSON.pretty_generate(sensu_events)}" if config[:debug]

    raise_sensu_events sensu_events unless sensu_events.length == 0

    message = "scenarios: #{scenario_count}"
    statuses.each do |status|
      message << ", #{status}: #{status_counts[status]}" unless status_counts[status] == 0
    end

    outcome = WARNING if scenario_count == 0

    case outcome
      when OK
        ok message
      when WARNING
        warning message
      when CRITICAL
        critical message
      when UNKNOWN
        unknown message
    end
  end

  def generate_name_from_scenario(scenario)
    check_name = scenario[:id]
    check_name += ";#{scenario[:profile]}" if scenario.has_key? :profile

    check_name = check_name.gsub(/\./, '-')
      .gsub(/;/, '.')
      .gsub(/[^a-zA-Z0-9\._-]/, '-')
      .gsub(/^\.+/, '')
      .gsub(/\.+$/, '')
      .gsub(/\.+/, '.')

    parts = []

    check_name.split('.').each do |part|
      part = part.gsub(/^-+/, '')
        .gsub(/-+$/, '')
        .gsub(/-+/, '-')

      parts << part unless part.length == 0
    end

    check_name = parts.join('.')
    check_name
  end

  def raise_sensu_events(sensu_events)
    sensu_events.each do |sensu_event|
      data = sensu_event.to_json

      socket = UDPSocket.new
      socket.send data, 0, '127.0.0.1', 3030
      socket.close
    end
  end

  def deep_dup(obj)
    Marshal.load(Marshal.dump(obj))
  end

  def generate_metrics_from_scenario(scenario, scenario_status, utc_timestamp)
    metrics = []

    if scenario_status == :passed
      scenario_duration = 0

      if scenario.has_key?(:steps)
        has_step_durations = false
        scenario_metric_prefix = "#{config[:metric_prefix]}.#{generate_name_from_scenario(scenario)}"

        scenario[:steps].each.with_index do |step, step_index|
          if step.has_key?(:result) && step[:result].has_key?(:duration)
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

end
