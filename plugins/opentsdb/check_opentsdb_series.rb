#!/usr/bin/env ruby
#
# OpenTSDB metric check
#
# This check compares OpenTSDB metrics
# with a threshold.
#
# OpenTSDB may provide the results for multiple
# hosts.  Check performs the threshold
# comparison for each host and generates an alert
# if at least one host fails the comparison.
#
# DEPENDENCIES:
# - sensu-plugin Ruby gem
# - nokogiri Ruby gem
# - continuum Ruby gem
#
# Written by Jessica Blackburn -- @jblackburn22 or http://github.com/jblackburn22
#
# Thanks Jesse Kempf for the test framework and providing good examples
# of creating testable code.
#
require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'nokogiri'
require 'continuum'

class CheckOpenTSDBSeries < Sensu::Plugin::Check::CLI

  COMPARISON_MAP = {
    'gt' => :>,
    'ge' => :>=,
    'lt' => :<,
    'le' => :<=,
    'eq' => :==
  }

  option :host,
    :description => "OpenTSDB API host",
    :long => "--host HOST",
    :default => "localhost"

  option :port,
    :description => "OpenTSDB API port",
    :long => "--port PORT",
    :proc => proc { |arg| arg.to_i },
    :default => 4242

  option :metric,
    :description => "OpenTSDB API metric",
    :long => "--metric comma separated METRIC_NAME"

  option :aggregator,
    :description => "OpenTSDB query aggregation function (default: sum)",
    :long => "--aggregator VALUE",
    :default => "sum"

  option :interval,
    :description => "the time interval (default: 5m-ago)",
    :long => "--interval VALUE",
    :default => "5m-ago"

  option :rate,
    :description => "Use rate of change instead of absolute value",
    :long => "--rate",
    :boolean => true,
    :default => false

  option :downsample,
    :description => "Reduce the number of data points",
    :long => "--downsample",
    :default => nil

  option :tags,
    :description => "OpenTSDB API query filters",
    :long => "--tags comma separated key=value pair"

  option :threshold,
    :description => "Value to compare the metric with",
    :long => "--threshold VALUE",
    :proc => proc { |arg| arg.to_f }

  option :ratio_threshold,
    :description => "Value to compare ratio of 2  metric with",
    :long => "--ratio_threshold VALUE",
    :proc => proc { |arg| arg.to_f }

  option :comparator,
    :description => "The operator to use for the comparison. Must be one of #{COMPARISON_MAP.keys.join(', ')}",
    :long => "--comparator VALUE",
    :proc => proc { |arg| COMPARISON_MAP[arg] },
    :default => :>

  def check_config
    # Check required parameters
    [:metric, :tags].each do |key|
      unknown "Missing require parameter #{key}" unless config[key]
    end

    # Check values of parameters
    unknown "Unknown comparator (#{config[:comparator]}). Valid options: {#{COMPARISON_MAP.keys.join(',')}}." unless config[:comparator].is_a?(Symbol)

    # Check combination of parameters
    if config[:ratio_threshold]
      unknown "Must set either threshold (#{config[:threshold]}) or ratio_threshold (#{config[:ratio_threshold]}) parameter but not both." if config[:threshold]

      metric_count = config[:metric].split(',').length
      unless metric_count == 2
        unknown "Must specify only 2 metrics when using ratio_threshold parameter"
      end

    else
      unknown "Must set either threshold or ratio_threshold parameter." unless config[:threshold]
    end
  end

  def run
    check_config

    if config[:threshold]
      run_threshold_check
    else
      run_ratio_check
    end
  end

  def get_data(metric)
    client = Continuum::Client.new(config[:host], config[:port])

    suggestion = client.suggest(metric)
    if suggestion.empty?
      critical "Invalid metric (#{metric}) specified."
    elsif suggestion.length > 1 and !suggestion.include?(metric)
      critical "The specific metric is abiguous. Is the appropriate metric one of these [#{suggestion.inspect}]?"
    end

    # Build metric part of the query
    query_metric_parameters = [config[:aggregator]]
    query_metric_parameters << "rate" if config[:rate]
    query_metric_parameters << config[:downsample] if config[:downsample]
    query_metric_parameters << "#{metric}{#{config[:tags]}}"

    begin
      client.query(
        :format  => :ascii,
        :start   => config[:interval],
        :m       => query_metric_parameters.join(':'),
        :nocache => true,
      )
    rescue Exception => e
      critical "Failed to retrieve #{config[:metric]} from OpenTSDB (#{config[:host]}:#{config[:port]}) -- #{e}."
    end
  end

  def parse_data(result)
    metrics = {}
    result.split("\n").each do |row|
      elements = row.split(' ')
      begin
        value = Float(elements[2])
      rescue Exception
        # OpenTSDB returns error responses in HTML.
        unknown "Query failed -- #{Nokogiri::HTML(result).search('body').map(&:text)}"
      end

      # Depending on the resolution of the data,
      # multiple data points will be returned.
      # The last data point is the most recent.
      #
      # The data is space separated with metric, time, value,
      # and optional tags.

      if elements.length > 2
        metrics[elements.drop(3).join(':')] = value
      else
        metrics['_'] = value
      end
    end

    metrics
  end

  def check_threshold(result)
    threshold = config[:threshold].to_f
    comparator = config[:comparator]

    # Depending on the tags, there may be multiple data sets, the threshold
    # comparison is done per group.
    failed_tags = []
    parse_data(result).each do |metric, value|
      failed_tags << metric unless value.send(comparator, threshold)
    end

    failed_tags
  end

  def run_threshold_check
    failed = {}
    config[:metric].split(',').each do |metric|
      failed_tags = check_threshold(get_data(metric))
      failed[metric] = failed_tags unless failed_tags.empty?
    end

    if failed.empty?
      ok "All metrics (#{config[:metric]}) are good"
    else
      message = "Check failed (#{config[:comparator]} #{config[:threshold]}) for "
      failed.each do |metric, tags|
        message += "metric #{metric} with tags #{tags.join(', ')}"
      end
      critical message
    end

  end

  def check_ratio(results)
    threshold = config[:ratio_threshold].to_f
    comparator = config[:comparator]

    # Depending on the tags, there may be multiple data sets, the threshold
    # comparison is done per group.
    failed_tags = []
    results[0].keys.each do |series|
      unless results[1].key?(series)
        puts "debug:  skipping series #{series} since it doesn't exist in #{metrics[1]}"
        next
      end

      critical "Invalid division by zero in tag #{series}" if results[1][series] == 0

      ratio = results[0][series] / results[1][series]
      failed_tags << series unless ratio.send(comparator, threshold)
    end

    failed_tags
  end

  def run_ratio_check
    threshold = config[:ratio_threshold].to_f
    comparator = config[:comparator]
    metrics = config[:metric].split(',')

    results = []
    metrics.each do |metric|
      results << parse_data(get_data(metric))
    end

    failed_tags = check_ratio(results)
    if failed_tags.empty?
      ok "Check OK (#{comparator} #{threshold}) for #{metrics[0]}/#{metrics[1]}"
    else
      message = "Check failed (#{comparator} #{threshold}) for #{metrics[0]}/#{metrics[1]} and tags #{failed_tags.join(', ')}"
      critical message
    end
  end

end
