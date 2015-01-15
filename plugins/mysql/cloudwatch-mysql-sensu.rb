#! /usr/bin/env ruby
#
#   <script name>
#
# DESCRIPTION:
#   what is this thing supposed to do, monitor?  How do alerts or
#   alarms work?
#
# OUTPUT:
#   plain text, metric data, etc
#
# PLATFORMS:
#   Linux, Windows, BSD, Solaris, etc
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: <?>
#
# USAGE:
#   example commands
#
# NOTES:
#   Does it behave differently on specific platforms, specific use cases, etc
#
# LICENSE:
#   <your name>  <your email>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

# !/usr/bin/env ruby
#
# Amazon RDS cloudwatch sensu plugin
# ===
#
# Dependencies
# -----------
# - http://docs.aws.amazon.com/AmazonRDS/latest/CommandLineReference/StartCLI.html
#
#
# Authors: Micah Hoffmann <https://github.com/SeattleMicah> Kristopher Zentner <https://github.com/kaezi>
#
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'aws/cloud_watch'
require 'optparse'
require 'pp'

aws_access_key_id = ''
aws_secret_key = ''
aws_region = ''
aws_debug = false

options = {}
optparse = OptionParser.new do|opts|

  opts.on('-h', '--help', '') do
    puts opts
    exit
  end

  opts.on('-H', '--host HOST', 'Hostname') do |host|
    options[:host] = host
  end

  opts.on('-w', '--warn WARN', 'Warning threshold') do |warn|
    options[:warn] = warn
  end

  opts.on('-c', '--crit CRIT', 'Critical threshold') do |crit|
    options[:crit] = crit
  end

  opts.on('-s', '--stat STAT', 'Statistic') do|stat|
    options[:stat] = stat
  end

  opts.on('-l', '--lessthan', 'Threshold is less than') do|lessthan|
    options[:lessthan] = lessthan
  end

end
begin
  optparse.parse!
  mandatory = [:warn, :crit, :stat, :host]                         # Enforce the presence of
  missing = mandatory.select { |param| options[param].nil? }        # the -t and -f switches
  unless missing.empty?                                            #
    puts "Missing options: #{missing.join(', ')}"                  #
    puts optparse                                                  #
    exit                                                           #
  end                                                              #
rescue OptionParser::InvalidOption, OptionParser::MissingArgument  #
  puts $ERROR_INFO.to_s                                                     # Friendly output when parsing fails
  puts optparse                                                    #
  exit                                                             #
end

AWS.config(access_key_id: aws_access_key_id,
           secret_access_key: aws_secret_key,
           region: aws_region,
           http_wire_trace: aws_debug)

metric = AWS::CloudWatch::Metric.new('AWS/RDS', "#{options[:stat]}",
                                     dimensions: [
                                       { name: 'DBInstanceIdentifier', value: "#{options[:host]}" }
                                     ])
stats = metric.statistics(
  start_time: Time.now - 600,
  end_time: Time.now,
  statistics: ['Average'])
latest = stats.first
# puts "#{stats.metric.name}: #{latest[:average]} #{latest[:unit]}"
# puts "#{options[:crit].to_f}"
if latest.nil?
  msg = "WARNING: #{options[:host]} is not returning data! Is it deleted? Slave dead? "
  msg += 'It could possibly mean there is no data to return, but make sure host is alive!'
  puts msg
  exit 2
end

average = latest[:average]
unit = latest[:unit]

# Determine the unit for the average returned and convert if needed
if unit == 'Bytes' && options[:stat] == 'FreeStorageSpace'
  average = (latest[:average] / 1_073_741_824).round(0)
  unit = 'GigaBytes'
elsif unit == 'Bytes'
  average = (latest[:average] / 1_048_576).round(0)
  unit = 'MegaBytes'
else
  average = latest[:average]
end

# Depending on if the stat is less than or greater than use the -l option
if options[:lessthan] == true
  # Begin the check of the average and against the warn and crit parameters
  if average.to_f < options[:crit].to_f
    puts "CRITICAL: #{options[:host]} statistic #{options[:stat]} is at #{average} #{unit} which is below threshold #{options[:crit]} #{unit}"
    exit 1
  elsif average.to_f < options[:warn].to_f
    puts "WARNING: #{options[:host]} statistic #{options[:stat]} is at #{average} #{unit} which is below threshold #{options[:warn]} #{unit}"
    exit 2
  else
    puts "OK: #{options[:host]} statistic #{options[:stat]} is #{average} #{unit}"
  end
  else
    if average.to_f > options[:crit].to_f
      puts "CRITICAL: #{options[:host]} statistic #{options[:stat]} is at #{average} #{unit} which is above threshold #{options[:crit]} #{unit}"
      exit 1
    elsif average.to_f > options[:warn].to_f
      puts "WARNING: #{options[:host]} statistic #{options[:stat]} is at #{average} #{unit} which is above threshold #{options[:warn]} #{unit}"
      exit 2
    else
      puts "OK: #{options[:host]} statistic #{options[:stat]} is #{average} #{unit}"
    end
end
