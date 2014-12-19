#! /usr/bin/env ruby
#
#   check-rspec
#
# DESCRIPTION:
#   Runs RSpec tests.
#   Raises a warning event for each individual failed test.
#   Also raises a single critical event if tests are failing.
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
#   gem: rspec
#   gem: socket
#
# USAGE:
#   Run entire suite of tests
#   check-rspec -d /tmp/my_tests
#
#   Run only one set of tests
#   check-rspec -d /tmp/my_tests -s spec/test_one.rb
#
#   Run tests with all options (except environment variables)
#   check-rspec -b /usr/bin/ruby -i bin/rspec -d /tmp/my_tests -s spec
#
#   Run tests with required options and multiple environment variables
#   check-rspec -d /tmp/my_tests -e "aws_access_key_id=XX aws_secret_access_key=XX"
#
# NOTES:
#
# LICENSE:
#   Copyright 2014 Sonian, Inc. and contributors. <support@sensuapp.org>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'json'
require 'socket'
require 'rspec'
require 'sensu-plugin/check/cli'

class CheckRspec < Sensu::Plugin::Check::CLI
  option :ruby_bin,
         short: '-b ruby',
         long: '--ruby-bin ruby',
         default: 'ruby'

  option :rspec_bin,
         short: '-i rspec',
         long: '--rspec-bin rspec',
         default: 'rspec'

  option :tests_dir,
         short: '-d /tmp/my_tests',
         long: '--tests-dir /tmp/my_tests',
         required: true

  option :spec_dir,
         short: '-s spec',
         long: '--spec-dir spec',
         default: 'spec'

  option :environment_variables,
         short: '-e aws_access_key_id=XXX',
         long: '--env-var aws_access_key_id=XXX',
         required: false

  option :handler,
         short: '-l HANDLER',
         long: '--handler HANDLER',
         default: 'default'

  def sensu_client_socket(msg)
    u = UDPSocket.new
    u.send(msg + "\n", 0, '127.0.0.1', 3030)
  end

  def send_ok(check_name, msg)
    d = { 'name' => check_name, 'status' => 0, 'output' => "OK: #{msg}", 'handler' => config[:handler] }
    sensu_client_socket d.to_json
  end

  def send_warning(check_name, msg)
    d = { 'name' => check_name, 'status' => 1, 'output' => "WARNING: #{msg}", 'handler' => config[:handler] }
    sensu_client_socket d.to_json
  end

  def run
    cd  = "cd #{config[:tests_dir]};"
    run = "#{config[:environment_variables]} #{config[:ruby_bin]} -S #{config[:rspec_bin]} #{config[:spec_dir]} -f json"

    rspec_results = `#{cd} #{run}`
    parsed        = JSON.parse(rspec_results)

    parsed['examples'].each do |rspec_test|
      test_name = rspec_test['file_path'].split('/')[-1] + '_' + rspec_test['line_number'].to_s
      output    = rspec_test['full_description']

      if rspec_test['status'] == 'passed'
        send_ok(test_name, output)
      else
        send_warning(test_name, output)
      end
    end

    summary       = parsed['summary_line']
    failure_count = summary.split[2]

    puts summary

    if failure_count == '0'
      exit_with(:ok, summary)
    else
      exit_with(:critical, summary)
    end
  end

  def exit_with(sym, message)
    case sym
    when :ok
      ok message
    when :critical
      critical message
    else
      unknown message
    end
  end
end
