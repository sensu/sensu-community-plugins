#! /usr/bin/env ruby
#
#   <script name>
#
# DESCRIPTION:
#   Get time series values from Graphite and create events based on values
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: json
#   gem: socket
#   gem: array_stats
#   gem: net/http
#
# USAGE:
#   #YELLOW
#
# NOTES:
#
# LICENSE:
#   Copyright 2012 Ulf Mansson @ Recorded Future
#   Modifications by Chris Jansen to support wildcard targets
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'json'
require 'net/http'
require 'socket'
require 'array_stats'

class Graphite < Sensu::Plugin::Check::CLI
  option :host,
         short: '-h HOST',
         long: '--host HOST',
         description: 'Graphite host to connect to, include port',
         required: true

  option :target,
         description: 'The graphite metric name. Could be a comma separated list of metric names.',
         short: '-t TARGET',
         long: '--target TARGET',
         required: true

  option :period,
         description: 'The period back in time to extract from Graphite and compare with. Use 24hours,2days etc, same format as in Graphite',
         short: '-p PERIOD',
         long: '--period PERIOD',
         default: '2hours'

  option :updated_since,
         description: 'The graphite value should have been updated within UPDATED_SINCE seconds, default to 600 seconds',
         short: '-u UPDATED_SINCE',
         long: '--updated_since UPDATED_SINCE',
         default: 600

  option :acceptable_diff_percentage,
         description: 'The acceptable diff from max values in percentage, used in check_function_increasing',
         short: '-d ACCEPTABLE_DIFF_PERCENTAGE',
         long: '--acceptable_diff_percentage ACCEPTABLE_DIFF_PERCENTAGE',
         default: 0

  option :check_function_increasing,
         description: 'Check that value is increasing or equal over time (use acceptable_diff_percentage if it should allow to be lower)',
         short: '-i',
         long: '--check_function_decreasing',
         default: false,
         boolean: true

  option :greater_than,
         description: 'Change whether value is greater than or less than check',
         short: '-g',
         long: '--greater_than',
         default: false

  option :check_last,
         description: 'Check that the last value in GRAPHITE is greater/less than VALUE',
         short: '-l VALUE',
         long: '--last VALUE',
         default: nil

  option :ignore_nulls,
         description: 'Do not error on null values, used in check_function_increasing',
         short: '-n',
         long: '--ignore_nulls',
         default: false,
         boolean: true

  option :concat_output,
         description: 'Include warning messages in output even if overall status is critical',
         short: '-c',
         long: '--concat_output',
         default: false,
         boolean: true

  option :short_output,
         description: 'Report only the highest status per series in output',
         short: '-s',
         long: '--short_output',
         default: false,
         boolean: true

  option :check_average,
         description: 'MAX_VALUE should be greater than the average of Graphite values from PERIOD',
         short: '-a MAX_VALUE',
         long: '--average_value MAX_VALUE'

  option :data_points,
         description: 'Number of data points to include in average check (smooths out spikes)',
         short: '-d VALUE',
         long: '--data_points VALUE',
         default: 1

  option :check_average_percent,
         description: 'MAX_VALUE% should be greater than the average of Graphite values from PERIOD',
         short: '-b MAX_VALUE',
         long: '--average_percent_value MAX_VALUE'

  option :percentile,
         description: 'Percentile value, should be used in conjunction with percentile_value, defaults to 90',
         long: '--percentile PERCENTILE',
         default: 90

  option :check_percentile,
         description: 'Values should not be greater than the VALUE of Graphite values from PERIOD',
         long: '--percentile_value VALUE'

  option :http_user,
         description: 'Basic HTTP authentication user',
         short: '-U USER',
         long: '--http-user USER',
         default: nil

  option :http_password,
         description: 'Basic HTTP authentication password',
         short: '-P PASSWORD',
         long: '--http-password USER',
         default: nil

  def initialize
    super
    @graphite_cache = {}
  end

  def graphite_cache(target = nil)
    # #YELLOW
    if @graphite_cache.key?(target) # rubocop:disable GuardClause
      graphite_value = @graphite_cache[target].select { |value| value[:period] == @period }
      graphite_value if graphite_value.size > 0
    end
  end

  # Create a graphite url from params
  #
  #
  def graphite_url(target = nil)
    url = "#{config[:host]}/render/"
    url = 'http://' + url unless url[0..3] == 'http'
    # #YELLOW
    url = url + "?target=#{target}" if target # rubocop:disable Style/SelfAssignment
    URI.parse(url)
  end

  def get_levels(config_param)
    values = config_param.split(',')
    i = 0
    levels = {}
    %w(warning error fatal).each do |type|
      levels[type] = values[i] if values[i]
      i += 1
    end
    levels
  end

  def get_graphite_values(target)
    cache_value = graphite_cache target
    return cache_value if cache_value
    params = {
      target: target,
      from: "-#{@period}",
      format: 'json'
    }

    req = Net::HTTP::Post.new(graphite_url.path)

    # If the basic http authentication credentials have been provided, then use them
    if !config[:http_user].nil? && !config[:http_password].nil?
      req.basic_auth(config[:http_user], config[:http_password])
    end

    req.set_form_data(params)
    resp = Net::HTTP.new(graphite_url.host, graphite_url.port).start { |http| http.request(req) }
    data = JSON.parse(resp.body)
    @graphite_cache[target] = []
    if data.size > 0
      data.each { |d| @graphite_cache[target] << { target: d['target'], period: @period, datapoints: d['datapoints'] } }
      graphite_cache target
    else
      nil
    end
  end

  # Will give max values for [0..-2]
  def max_graphite_value(target)
    max_values = {}
    values = get_graphite_values target
    if values
      values.each do | val |
        max = get_max_value(val[:datapoints])
        max_values[val[:target]] = max
      end
    end
    max_values
  end

  def get_max_value(values)
    if values
      values.map { |i| i[0] ? i[0] : 0 }[0..-2].max
    else
      nil
    end
  end

  def last_graphite_metric(target, count = 1)
    last_values = {}
    values = get_graphite_values target
    if values
      values.each do | val |
        last = get_last_metric(val[:datapoints], count)
        last_values[val[:target]] = last
      end
    end
    last_values
  end

  def get_last_metric(values, count = 1)
    if values
      ret = []
      values_size = values.size
      count = values_size if count > values_size
      while count > 0
        values_size -= 1
        break if values[values_size].nil?
        count -= 1 if values[values_size][0]
        ret.push(values[values_size]) if values[values_size][0]
      end
      ret
    else
      nil
    end
  end

  def last_graphite_value(target, count = 1)
    last_metrics = last_graphite_metric(target, count)
    last_values = {}
    if last_metrics
      last_metrics.each do | target_name, metrics |
        last_values[target_name] = metrics.map { | metric |  metric[0] }.mean
      end
    end
    last_values
  end

  def been_updated_since(target, time, updated_since)
    last_time_stamp = last_graphite_metric target
    warnings = []
    if last_time_stamp
      last_time_stamp.each do | target_name, value |
        last_time_stamp_bool = value[1] > time.to_i ? true : false
        warnings << "The metric #{target_name} has not been updated in #{updated_since} seconds" unless last_time_stamp_bool
      end
    end
    warnings
  end

  def greater_less
    return 'greater' if config[:greater_than]
    return 'less' unless config[:greater_than]
  end

  def check_increasing(target)
    updated_since = config[:updated_since].to_i
    time_to_be_updated_since = Time.now - updated_since
    critical_errors = []
    warnings = []
    max_gv = max_graphite_value target
    last_gv = last_graphite_value target
    if last_gv.is_a?(Hash) && max_gv.is_a?(Hash)
      # #YELLOW
      last_gv.each do | target_name, value | # rubocop:disable Style/Next
        if value && max_gv[target_name]
          last = value
          max = max_gv[target_name]
          if max > last * (1 + config[:acceptable_diff_percentage].to_f / 100)
            msg = "The metric #{target} with last value #{last} is less than max value #{max} during #{config[:period]} period"
            critical_errors << msg
          end
        end
      end
    else
      warnings << "Could not found any value in Graphite for metric #{target}, see #{graphite_url(target)}"
    end
    unless config[:ignore_nulls]
      warnings.concat(been_updated_since(target, time_to_be_updated_since, updated_since))
    end
    [warnings, critical_errors, []]
  end

  def check_average_percent(target, max_values, data_points = 1)
    values = get_graphite_values target
    last_values = last_graphite_value(target, data_points)
    return [[], [], []] unless values
    warnings = []
    criticals = []
    fatal = []
    values.each do | data |
      target = data[:target]
      values_pair = data[:datapoints]
      values_array = values_pair.select(&:first).map { |v| v.first unless v.first.nil? }
      # #YELLOW
      avg_value = values_array.reduce { |sum, el| sum + el if el }.to_f / values_array.size # rubocop:disable SingleLineBlockParams
      last_value = last_values[target]
      percent = last_value / avg_value unless last_value.nil? || avg_value.nil?
      # #YELLOW
      %w(fatal error warning).each do |type|  # rubocop:disable Style/Next
        next unless max_values.key?(type)
        max_value = max_values[type]
        var1 = config[:greater_than] ? percent : max_value.to_f
        var2 = config[:greater_than] ? max_value.to_f : percent
        if !percent.nil? && var1 > var2 && (values_array.size > 0 || !config[:ignore_nulls])
          text = "The last value of metric #{target} is #{percent}% #{greater_less} than allowed #{max_value}% of the average value #{avg_value}"
          case type
          when 'warning'
            warnings <<  text
          when 'error'
            criticals << text
          when 'fatal'
            fatal << text
          else
            fail "Unknown type #{type}"
          end
          break if config[:short_output]
        end
      end
    end
    [warnings, criticals, fatal]
  end

  def check_average(target, max_values)
    values = get_graphite_values target
    return [[], [], []] unless values
    warnings = []
    criticals = []
    fatal = []
    values.each do | data |
      target = data[:target]
      values_pair = data[:datapoints]
      values_array = values_pair.select(&:first).map { |v| v.first unless v.first.nil? }
      # #YELLOW
      avg_value = values_array.reduce { |sum, el| sum + el if el }.to_f / values_array.size # rubocop:disable SingleLineBlockParams
      # YELLOW
      %w(fatal error warning).each do |type|  # rubocop:disable Style/Next
        next unless max_values.key?(type)
        max_value = max_values[type]
        var1 = config[:greater_than] ? avg_value : max_value.to_f
        var2 = config[:greater_than] ? max_value.to_f : avg_value
        if var1 > var2 && (values_array.size > 0 || !config[:ignore_nulls])
          text = "The average value of metric #{target} is #{avg_value} that is #{greater_less} than allowed average of #{max_value}"
          case type
          when 'warning'
            warnings <<  text
          when 'error'
            criticals << text
          when 'fatal'
            fatal << text
          else
            fail "Unknown type #{type}"
          end
          break if config[:short_output]
        end
      end
    end
    [warnings, criticals, fatal]
  end

  def check_percentile(target, max_values, percentile, data_points = 1)
    values = get_graphite_values target
    last_values = last_graphite_value(target, data_points)
    return [[], [], []] unless values
    warnings = []
    criticals = []
    fatal = []
    values.each do | data |
      target = data[:target]
      values_pair = data[:datapoints]
      values_array = values_pair.select(&:first).map { |v| v.first unless v.first.nil? }
      percentile_value = values_array.percentile(percentile)
      last_value = last_values[target]
      percent = last_value / percentile_value unless last_value.nil? || percentile_value.nil?
      # #YELLOW
      %w(fatal error warning).each do |type|  # rubocop:disable Style/Next
        next unless max_values.key?(type)
        max_value = max_values[type]
        var1 = config[:greater_than] ? percent : max_value.to_f
        var2 = config[:greater_than] ? max_value.to_f : percent
        if !percentile_value.nil? && var1 > var2
          text = "The percentile value of metric #{target} (#{last_value}) is #{greater_less} than the
            #{percentile}th percentile (#{percentile_value}) by more than #{max_value}%"
          case type
          when 'warning'
            warnings <<  text
          when 'error'
            criticals << text
          when 'fatal'
            fatal << text
          else
            fail "Unknown type #{type}"
          end
          break if config[:short_output]
        end
      end
    end
    [warnings, criticals, fatal]
  end

  def check_last(target, max_values)
    last_targets = last_graphite_metric target
    return [[], [], []] unless last_targets
    warnings = []
    criticals = []
    fatal = []
    # #YELLOW
    last_targets.each do | target_name, last |   # rubocop:disable Style/Next
      last_value = last.first
      unless last_value.nil?
        # #YELLOW
        %w(fatal error warning).each do |type|   # rubocop:disable Style/Next
          next unless max_values.key?(type)
          max_value = max_values[type]
          var1 = config[:greater_than] ? last_value : max_value.to_f
          var2 = config[:greater_than] ? max_value.to_f : last_value
          if var1 > var2
            text = "The metric #{target_name} is #{last_value} that is #{greater_less} than max allowed #{max_value}"
            case type
            when 'warning'
              warnings <<  text
            when 'error'
              criticals << text
            when 'fatal'
              fatal << text
            else
              fail "Unknown type #{type}"
            end
            break if config[:short_output]
          end
        end
      end
    end
    [warnings, criticals, fatal]
  end

  def run
    targets = config[:target].split(',')
    @period = config[:period]
    critical_errors = []
    warnings = []
    fatals = []
    # #YELLOW
    targets.each do |target|   # rubocop:disable Style/Next
      if config[:check_function_increasing]
        inc_warnings, inc_critical, inc_fatal = check_increasing target
        warnings += inc_warnings
        critical_errors += inc_critical
        fatals += inc_fatal
      end
      if config[:check_last]
        max_values = get_levels config[:check_last]
        lt_warnings, lt_critical, lt_fatal = check_last(target, max_values)
        warnings += lt_warnings
        critical_errors += lt_critical
        fatals += lt_fatal
      end
      if config[:check_average]
        max_values = get_levels config[:check_average]
        avg_warnings, avg_critical, avg_fatal = check_average(target, max_values)
        warnings += avg_warnings
        critical_errors += avg_critical
        fatals += avg_fatal
      end
      if config[:check_average_percent]
        max_values = get_levels config[:check_average_percent]
        avg_warnings, avg_critical, avg_fatal = check_average_percent(target, max_values, config[:data_points].to_i)
        warnings += avg_warnings
        critical_errors += avg_critical
        fatals += avg_fatal
      end
      if config[:check_percentile]
        max_values = get_levels config[:check_percentile]
        pct_warnings, pct_critical, pct_fatal = check_percentile(target, max_values, config[:percentile].to_i, config[:data_points].to_i)
        warnings += pct_warnings
        critical_errors += pct_critical
        fatals += pct_fatal
      end
    end
    fatals_string = fatals.size > 0 ? fatals.join("\n") : ''
    criticals_string = critical_errors.size > 0 ? critical_errors.join("\n") : ''
    warnings_string = warnings.size > 0 ? warnings.join("\n") : ''

    if config[:concat_output]
      fatals_string = fatals_string + "\n" + criticals_string if critical_errors.size > 0
      fatals_string = fatals_string + "\nGraphite WARNING: " + warnings_string if warnings.size > 0
      criticals_string = criticals_string + "\nGraphite WARNING: " + warnings_string if warnings.size > 0
      critical fatals_string if fatals.size > 0
      critical criticals_string if critical_errors.size > 0
      warning warnings_string if warnings.size > 0
    else
      critical fatals_string if fatals.size > 0
      critical criticals_string if critical_errors.size > 0
      warning warnings_string if warnings.size > 0
    end
    ok
  end
end
