#!/usr/bin/env ruby
#
require 'aws-sdk'
require 'optparse'
require 'pp'

access_key_id=""
secret_key=""

options = {}
optparse = OptionParser.new do|opts|
  opts.on( '-h', '--help', '' ) do
    puts opts
    exit
  end
  opts.on( '-H', '--host HOST','Warning threshold' ) do|host|
    options[:host] = host
  end
   opts.on( '-w', '--warn WARN','Warning threshold' ) do|warn|
    options[:warn] = warn
  end
  opts.on( '-c', '--crit CRIT','Critical threshold' ) do|crit|
    options[:crit] = crit
  end
  opts.on( '-s', '--stat STAT','Statistic' ) do|stat|
    options[:stat] = stat
  end
  opts.on( '-l', '--lessthan','Threshold is less than' ) do|lessthan|
    options[:lessthan] = lessthan
  end
end
begin
  optparse.parse!
  mandatory = [:warn,:crit,:stat,:host]                                         # Enforce the presence of
  missing = mandatory.select{ |param| options[param].nil? }        # the -t and -f switches
  if not missing.empty?                                            #
    puts "Missing options: #{missing.join(', ')}"                  #
    puts optparse                                                  #
    exit                                                           #
  end                                                              #
rescue OptionParser::InvalidOption, OptionParser::MissingArgument      #
  puts $!.to_s                                                           # Friendly output when parsing fails
  puts optparse                                                          #
  exit                                                                   #
end

AWS.config({
  :access_key_id => access_key_id,
  :secret_access_key => secret_key
})

cw = AWS::CloudWatch.new
metric = AWS::CloudWatch::Metric.new('AWS/RDS', "#{options[:stat]}", 
	{:dimensions => [
		{:name => "DBInstanceIdentifier", :value => "#{options[:host]}"}
	]})
stats = metric.statistics(
	:start_time => Time.now - 600,
	:end_time => Time.now,
	:statistics => ['Average'])
latest = stats.first
#puts "#{stats.metric.name}: #{latest[:average]} #{latest[:unit]}"
#puts "#{options[:crit].to_f}"
if latest.nil?
  puts "WARNING: #{options[:host]} is not returning data! Is it deleted? Slave dead? It could possibly mean there is no data to return, but make sure host is alive!"
exit 2
end
average = latest[:average]
unit = latest[:unit]
    # Determine the unit for the average returned and convert if needed
    if unit == "Bytes" && options[:stat] == "FreeStorageSpace"
      average = (latest[:average]/1073741824).round(0)
      unit = "GigaBytes"
    elsif unit == "Bytes"
      average = (latest[:average]/1048576).round(0)
      unit = "MegaBytes"
    else
      average = latest[:average]
    end

    # Depending on if the stat is less than or greater than use the -l option
    if options[:lessthan] == true
    # Begin the check of the average and against the warn and crit parameters
      if average.to_f < options[:crit].to_f
	  puts "CRITICAL: #{options[:host]} statistic #{options[:stat]} is at #{average} #{unit} which is below threshold #{options[:crit]} "
	  exit 1
      elsif average.to_f < options[:warn].to_f
	  puts "WARNING: #{options[:host]} statistic #{options[:stat]} is at #{average} #{unit} which is below threshold #{options[:warn]}"
	  exit 2
      else 
	  puts "OK: #{options[:host]} statistic #{options[:stat]} is #{average} #{unit}"
      end
    else
      if average.to_f > options[:crit].to_f
	  puts "CRITICAL: #{options[:host]} statistic #{options[:stat]} is at #{average} #{unit} which is above threshold #{options[:crit]} "
	  exit 1
      elsif average.to_f > options[:warn].to_f
	  puts "WARNING: #{options[:host]} statistic #{options[:stat]} is at #{average} #{unit} which is above threshold #{options[:warn]}"
	  exit 2
      else 
	  puts "OK: #{options[:host]} statistic #{options[:stat]} is #{average} #{unit}"
      end
    end
