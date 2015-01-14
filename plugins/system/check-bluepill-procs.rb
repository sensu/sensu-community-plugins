#! /usr/bin/env ruby
#
#   check-bluepill-procs
#
# DESCRIPTION:
#   This plugin monitors the status of applications and processes
#   running under the bluepill process supervisor.
#
#   Specify applications to monitor with -a [APP1,APP2]
#   If this option is not provided, this check will monitor the processes
#   of all the applications that bluepill has loaded.
#
# OUTPUT:
#   plain text
#   Returns CRITICAL if any process is down or if a manually specified
#   application has no processes loaded
#   Returns WARNING if any process is starting or unmonitored
#   Returns OK if all processes for all specified applications are 'up'
#   or bluepill is not in $PATH
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: English
#
# USAGE:
#
# NOTES:
#
# LICENSE:
#   James Legg mail@jameslegg.co.uk
#   Matt Greensmith mgreensmith@cozy.co
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'English'

# Check application processes running under bluepill control
class CheckBluepill < Sensu::Plugin::Check::CLI
  # a single application to monitor, or multiple applications, comma-separated.
  # check all applications if option not provided.
  option :apps,
         short: '-a [APPS]',
         long: '--applications [APPS]'

  option :debug,
         long: '--debug',
         description: 'Verbose output'

  option :sudo,
         short: '-s',
         long: '--sudo',
         description: 'exec bluepill with sudo (needs passwordless)'

  def merge_output(orig, add)
    orig.keys.each { |k| orig[k].push(*add[k]) }
    orig
  end

  def bluepill_application_status(name)
    out = { name: [], ok: [], warn: [], crit: [], err: [] }
    app_status = `#{config[:sudo] ? 'sudo ' : nil }bluepill #{name} status 2<&1`
    name = 'Unknown' if name == ''
    out[:name] << name
    puts "***** DEBUG: bluepill #{name} status *****\n#{app_status}" if config[:debug]
    processes_found = 0
    # #YELLOW
    app_status.each_line do |line| # rubocop:disable Style/Next
      if line =~ /(pid:)/
        processes_found += 1
        case line
        when /unmonitored$/
          out[:warn] << "#{name}::#{line}".strip
          next
        when /starting$/
          out[:warn] << "#{name}::#{line}".strip
          next
        when /down$/
          out[:crit] << "#{name}::#{line}".strip
          next
        when /up$/
          out[:ok] << "#{name}::#{line}".strip
          next
        end
      end
    end
    out[:err] << name if processes_found == 0
    puts "***** DEBUG: bluepill #{name} status parsed ******\n#{out.inspect}" if config[:debug]
    out
  end

  def parse_output(out)
    puts "***** DEBUG: Full output hash ******\n#{out.inspect}" if config[:debug]
    if !out[:crit].empty?
      critical "Bluepill process(es) critical:\n#{out[:crit].join("\n")}"
    elsif !out[:err].empty?
      critical "Bluepill process(es) not found for applications: #{out[:err].join(',')}"
    elsif !out[:warn].empty?
      warning "Bluepill process(es) warning:\n#{out[:warn].join("\n")}"
    else
      ok "Bluepill normal, #{out[:name].count} application(s) with #{out[:ok].count} process(es) up."
    end
  end

  def run
    # Check if Bluepill is installed
    `which bluepill`
    # #YELLOW
    unless $CHILD_STATUS.success? # rubocop:disable IfUnlessModifier
      ok 'bluepill not installed'
    end

    out = { name: [], ok: [], warn: [], crit: [], err: [] }

    if config[:apps]
      requested_apps = config[:apps].split(',').map(&:strip) || []
      puts "***** DEBUG: requested applications: #{requested_apps }*****" if config[:debug]
      requested_apps.each do |a|
        out = merge_output(out, bluepill_application_status(a))
      end
    else
      puts '***** DEBUG: checking all applications *****' if config[:debug]
      bluepill_status = `#{config[:sudo] ? 'sudo ' : nil }bluepill status 2>&1`
      if $CHILD_STATUS.success?
        # we have only one application loaded and bluepill is
        # 'helpfully' showing us only the status of that
        # application's processes. We can't get the name of the
        # application, however.
        puts '***** DEBUG: bluepill status short-circuited to show status of a single unknown application *****' if config[:debug]
        out = merge_output(out, bluepill_application_status(''))
      else
        # We either have multiple applications or no applications,
        # or maybe bluepill is completely borked.
        # (Returning non-zero when there are multiple applications
        # loaded seems bizarre, but hey, that's just me.)
        # We assume that no found applications is OK, since we only
        # get here if -a option is unset.
        # #YELLOW
        bluepill_status.each_line do |line| # rubocop:disable Style/Next
          if line =~ /^\s \d\.\s/
            app_name = line.split(/^\s \d\.\s/)[1].strip
            # #YELLOW
            puts "***** DEBUG: found an application: #{app_name} *****" if config[:debug] # rubocop:disable BlockNesting
            out = merge_output(out, bluepill_application_status(app_name))
          end
        end
      end
    end
    parse_output(out)
  end
end
