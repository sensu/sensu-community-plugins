#!/usr/bin/env ruby

#
# Checks a system for tripwire violations.
# ===
#
# DESCRIPTION:
# This plugin periodically runs a check of the tripwire intrusion detection tool and
# posts events for each violation found.
#
# The plugin assumes that tripwire has been configured and that a tripwire database
# is available that contains the desired state of the system.
#
# The plugin does note require that the database be on the target machine. If an http
# url is supplied via the -d option then the database will be retrieved via http before
# the check is run and deleted afterward.
#
# PLATFORMS:
#   linux
#
# DEPENDENCIES:
#   tripwire tool installed on the target machine
#
# USAGE:
# there are sensible defaults for each of the options so the check can reasonably
# be run with no options. It is configurably for most modes of use though and the
# option descriptions below are fairly self explanatory.
#
# Copyright 2013 Steve Gargan
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.
#
require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'json'
require 'open-uri'
require 'securerandom'

class TripwireCheck < Sensu::Plugin::Check::CLI

  option :binary,
    :short => "-b path/to/tripwire",
    :long => "--binary path/to/tripwire",
    :description => "tripwire binary to use, in case you hide yours",
    :required => false,
    :default => 'tripwire'

  option :sitekey,
    :short => "-s path/to/sitekey",
    :long => "--site-key path/to/sitekey",
    :description => "Site key used to decrypt the database that will be used in the validation",
    :required => false

  option :password,
    :short => "-P PASSWORD",
    :long => "--password PASSWORD",
    :description => "Password to unlock the keyfile",
    :required => false

  option :database,
    :short => "-d path_or_url_to_database",
    :long => "--database path_or_url_to_database. if an http url is supplied the database will be retrieved prior to the check",
    :description => "Database to use for the check",
    :required => false

  option :critical,
    :short => "-c critical severity",
    :long => "--critical critical severity",
    :description => "Tripwire severity greater than this is a critical error",
    :required => false,
    :default => '100'

  option :warn,
    :short => "-w warn severity",
    :long => "--warn warining severity",
    :description => "Tripwire severity greater than this is warning",
    :required => false,
    :default => '66'

  def run_tripwire
    site_key = (config[:sitekey] && "-S #{config[:sitekey]}") || ""
    database = retrieve_database
    database = (database && "-d #{database}") || ""
    `#{config[:binary]} --check #{site_key} #{database}`
  end

  def retrieve_database
    database = config[:database]

    if (database && database.start_with?("http"))
      id = SecureRandom.uuid
      tmp_db = "./twd-#{id}"
      begin
        open(tmp_db, 'wb') do |db|
          db << open(database).read
        end
      rescue Exception => e
        critical "Error loading database from #{database}. Message #{e.message}"
        exit 1
      end
      database = tmp_db
    end
    database
  end

  def cleanup
    Dir.glob('./twd-*') do |db|
    File.delete(db)
    end
  end

  def parse_violations(report)

    rule_match = 'Rule Name: (.*)'
    severity_level = 'Severity Level: (\d*)'
    violation_type = '(Added|Modified|Removed).*'
    quoted = '"([^"]*)"'

    violations = {}
    current_violation = nil
    current_list = nil
    report.each do |line|
      if m = line.match(rule_match) # rubocop:disable AssignmentInCondition
        name = m[1]
        current_violation = {name: name}
        violations[:name] = current_violation
      end

      if (m = line.match(severity_level))
        current_violation[:level] = m[1].to_i
      end

      if (m = line.match(violation_type)) && current_violation # rubocop:disable AssignmentInCondition
        current_list = []
        current_violation[m[1]] = current_list
      end

      if (m = line.match(quoted)) && current_list
        current_list << m[1]
      end
    end
    violations
  end

  def run
    begin
      report = run_tripwire.split("\n")
      violations = parse_violations report
      cleanup
    rescue Exception => e
      cleanup
      warning "Error running tripwire. #{e. message}"
      exit 1
    end

    violations.each do |name, violation|
      if violation[:level] >= config[:critical].to_i
        critical violation.to_json
      elsif violation[:level] >= config[:warn].to_i
        warning violation.to_json
      end
    end
    if violations.size == 0
        ok "no violations"
    end
  end
end
