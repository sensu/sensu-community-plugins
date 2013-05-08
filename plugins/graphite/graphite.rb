#!/usr/bin/env ruby
#
# Get time series values from Graphite and create events based on values
# ===
#
#
# Copyright 2012 Ulf Mansson @ Recorded Future
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'json'
require 'net/http'
require 'socket'

class Graphite < Sensu::Plugin::Check::CLI

  option :host,
         :short => "-h HOST",
         :long => "--host HOST",
         :description => "Graphite host to connect to, include port",
         :required => true

  option :target,
         :description => "The graphite metric name. Could be a comma separated list of metric names.",
         :short => "-t TARGET",
         :long => "--target TARGET",
         :required => true

  option :period,
         :description => "The period back in time to extract from Graphite and compare with. Use 24hours,2days etc, same format as in Graphite",
         :short => "-p PERIOD",
         :long => "--period PERIOD",
         :default => "2hours"

  option :updated_since,
         :description => "The graphite value should have been updated within UPDATED_SINCE seconds, default to 600 seconds",
         :short => "-u UPDATED_SINCE",
         :long => "--updated_since UPDATED_SINCE",
         :default => 600

  option :acceptable_diff_percentage,
         :description => "The acceptable diff from max values in percentage, used in check_function_increasing",
         :short => "-d ACCEPTABLE_DIFF_PERCENTAGE",
         :long => "--acceptable_diff_percentage ACCEPTABLE_DIFF_PERCENTAGE",
         :default => 0

  option :check_function_increasing,
         :description => "Check that value is increasing or equal over time (use acceptable_diff_percentage if it should allow to be lower)",
         :short => "-i",
         :long => "--check_function_decreasing",
         :default => false,
         :boolean => true

  option :check_greater_than,
         :description => "Check that last value in Graphite is not greater than VALUE",
         :short => "-g VALUE",
         :long => "--greater_than VALUE",
         :default => nil

  option :check_less_than,
         :description => "Check that the last value in GRAPHITE is less than VALUE",
         :short => "-l VALUE",
         :long => "--less_than VALUE",
         :default => nil

  option :check_greater_than_average,
         :description => "MAX_VALUE should be greater than the average of Graphite values from PERIOD",
         :short => "-a MAX_VALUE",
         :long => "--average_value MAX_VALUE"


  def initialize
    super
    @graphite_cache = []
  end

  def graphite_cache
    graphite_value = @graphite_cache.find {|value| value["target"]==@target && value["period"] == @period}
    graphite_value[:value] if graphite_value
  end

  # Create a graphite url from params
  #
  #
  def graphite_url (target = nil)
    url = "#{config[:host]}/render/"
    url = "http://" + url unless url[0..3] == "http"
    url = url + "?target=#{target}" if target
    URI.parse(url)
  end

  def get_levels(config_param)
    values = config_param.split(",")
    i = 0
    levels = {}
    %w{warning error fatal}.each do |type|
      levels[type] = values[i] if values[i]
      i += 1
    end
    levels
  end

  def get_graphite_values(target)
    cache_value = graphite_cache
    return cache_value if cache_value
    params = {
        :target => target,
        :from   => "-#{@period.to_s}",
        :format => 'json'
    }
    resp = Net::HTTP.post_form(graphite_url, params)
    data = JSON.parse(resp.body)
    if data.size > 0
      @graphite_cache << {:target => target, :period => @period, :value => data.first['datapoints']}
      data.first['datapoints'] #.select { |t| !t.first.nil? }.last.first
    else
      nil
    end

  end

  # Will give max values for [0..-2]
  def max_graphite_value(target)
    values = get_graphite_values target
    if values
      values.map {|i| i[0] ? i[0] : 0}[0..-2].max
    else
      nil
    end
  end

  def last_graphite_metric(target)
    values = get_graphite_values target
    if values
      count = values.size
      while count > 0
        count -= 1
        break if values[count][0]
      end
      values[count]
    else
      nil
    end
  end

  def last_graphite_value(target)
    last_metric = last_graphite_metric target
    last_metric ? last_metric[0] : nil
  end

  def has_been_updated_since(target, time)
    last_time_stamp = last_graphite_metric target
    last_time_stamp ? last_time_stamp[1] > time.to_i : false
  end

  def check_increasing(target)
    updated_since = config[:updated_since].to_i
    time_to_be_updated_since = Time.now - updated_since
    critical_errors = ""
    warnings = ""
    max_gv = max_graphite_value target
    last_gv = last_graphite_value target
    if last_gv && max_gv
      if max_gv > last_gv * (1 + config[:acceptable_diff_percentage].to_f / 100)
        critical_errors << "The metric #{target} with last value #{last_gv} is less than max value #{max_gv} during #{config[:period]} period, see #{graphite_url(target)}"
      end
    else
      warnings << "Could not found any value in Graphite for metric #{target}, see #{graphite_url(target)}"
    end
    warnings << "The metric #{target} has not been updated in #{updated_since.to_s} seconds" unless has_been_updated_since(target, time_to_be_updated_since)
    [warnings, critical_errors, nil]
  end

  def check_average(target,max_values)
    values_pair = get_graphite_values target
    return [[],[],[]] unless values_pair
    values = values_pair.find_all{|v| v.first}.map {|v| v.first if v.first != nil}
    avg_value = values.inject{ |sum, el| sum + el if el }.to_f / values.size
    warnings = []
    criticals = []
    fatal = []
    max_values.each_pair do |type, max_value|
      if avg_value < max_value.to_f
        text = "The average value of metric #{target} is #{avg_value} that is less than allowed average of #{max_value}"
        case type
          when "warning"
            warnings <<  text
          when "error"
            criticals << text
          when "fatal"
            fatal << text
          else
            raise "Unknown type #{type}"
        end
      end
    end
    [warnings, criticals, fatal]
  end

  def check_greater_than(target,max_values)
    last = last_graphite_metric(target)
    return [[],[],[]] unless last
    warnings = []
    criticals = []
    fatal = []
    last_value = last.first
    max_values.each_pair do |type, max_value|
      if last_value > max_value.to_f
        text = "The metric #{target} is #{last_value} that is higher than max allowed #{max_value}"
        case type
          when "warning"
            warnings <<  text
          when "error"
            criticals << text
          when "fatal"
            fatal << text
          else
            raise "Unknown type #{type}"
        end
      end
    end
    [warnings, criticals, fatal]
  end

  def check_less_than(target,min_values)
    last = last_graphite_metric(target)
    return [[],[],[]] unless last
    warnings = []
    criticals = []
    fatal = []
    last_value = last.first
    min_values.each_pair do |type, min_value|
      if last_value < min_value.to_f
        text = "The metric #{target} is #{last_value} that is lower than min allowed #{min_value}"
        case type
          when "warning"
            warnings <<  text
          when "error"
            criticals << text
          when "fatal"
            fatal << text
          else
            raise "Unknown type #{type}"
        end
      end
    end
    [warnings, criticals, fatal]
  end

  def run
    targets = config[:target].split(",")
    @period = config[:period]
    critical_errors = []
    warnings = []
    fatals = []
    targets.each do |target|
      if config[:check_function_increasing]
        inc_warnings, inc_critical, inc_fatal = check_increasing target
        warnings << inc_warnings
        critical_errors << inc_critical
        fatals << inc_fatal
      end
      if config[:check_greater_than]
        max_values = get_levels config[:check_greater_than]
        gt_warnings, gt_critical, gt_fatal = check_greater_than(target, max_values)
        warnings += gt_warnings
        critical_errors += gt_critical
        fatals += gt_fatal
      end
      if config[:check_less_than]
        max_values = get_levels config[:check_less_than]
        lt_warnings, lt_critical, lt_fatal = check_less_than(target, max_values)
        warnings += lt_warnings
        critical_errors += lt_critical
        fatals += lt_fatal
      end
      if config[:check_greater_than_average]
        max_values = get_levels config[:check_greater_than_average]
        avg_warnings, avg_critical, avg_fatal = check_average(target, max_values)
        warnings += avg_warnings
        critical_errors += avg_critical
        fatals += avg_fatal
      end
    end
    critical fatals.join("\n") if fatals.size > 0
    critical critical_errors.join("\n") if critical_errors.size > 0
    warning warnings.join("\n") if warnings.size > 0
    ok

  end

end
