#!/usr/bin/env ruby
# encoding: UTF-8
#  check-ssl-qualys.rb
#
# DESCRIPTION:
#   Runs a report using the Qualys SSL Labs API and then alerts if a
#   domiain does not meet the grade specified for *ALL* hosts that are
#   reachable from that domian.
#
#   The checks that are performed are documented on
#   https://www.ssllabs.com/index.html as are the range of grades.
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: rest-client
#   gem: json
#
# USAGE:
#   # Basic usage
#   check-ssl-qualys.rb -d <domain_name>
#   # Specify the CRITICAL and WARNING grades to a specific grade
#   check-ssl-qualys.rb -h <hostmame> -c <critical_grade> -w <warning_grade>
#   # Use --api-url to specify an alternate api host
#   check-ssl-qualys.rb -d <domain_name> -api-url <alternate_host>
#
# LICENSE:
#   Copyright 2015 William Cooke <will@bruisyard.eu>
#   Released under the same terms as Sensu (the MIT license); see LICENSE for
#   details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'rest-client'
require 'json'

# Checks a single DNS entry has a rating above a certain level
class CheckSSLQualys < Sensu::Plugin::Check::CLI
  # Current grades that are avaialble from the API
  GRADE_OPTIONS = ['A+', 'A', 'A-', 'B', 'C', 'D', 'E', 'F', 'T', 'M']

  option :domain,
         description: 'The domain to run the test against',
         short: '-d DOMAIN',
         long: '--domain DOMAIN',
         required: true

  option :api_url,
         description: 'The URL of the API to run against',
         long: '--api-url URL',
         default: 'https://api.ssllabs.com/api/v2/'

  option :warn,
         short: '-w GRADE',
         long: '--warn GRADE',
         description: 'WARNING if below this grade',
         proc: proc { |g| GRADE_OPTIONS.index(g) },
         default: 2 # 'A-'

  option :critical,
         short: '-c GRADE',
         long: '--critical GRADE',
         description: 'CRITICAL if below this grade',
         proc: proc { |g| GRADE_OPTIONS.index(g) },
         default: 3 # 'B'

  option :num_checks,
         short: '-n NUM_CHECKS',
         long: '--number-checks NUM_CHECKS',
         description: 'The number of checks to make before giving up',
         proc: proc { |t| t.to_i },
         default: 24

  option :between_checks,
         short: '-t SECONDS',
         long: '--time-between SECONDS',
         description: 'The time between each poll of the API',
         proc: proc { |t| t.to_i },
         default: 10

  def ssl_api_request(fromCache)
    params = { host: config[:domain] }
    params.merge!(startNew: 'on') unless fromCache
    r = RestClient.get("#{config[:api_url]}analyze", params: params)
    warning "HTTP#{r.code} recieved from API" unless r.code == 200
    JSON.parse(r.body)
  end

  def ssl_check(fromCache)
    json = ssl_api_request(fromCache)
    warning "ERROR on #{config[:domain]} check" if json['status'] == 'ERROR'
    json
  end

  def ssl_recheck
    1.upto(config[:num_checks]) do |step|
      json = ssl_check(step != 1)
      return json if json['status'] == 'READY'
      sleep(config[:between_checks])
    end
    warning 'Timeout waiting for check to finish'
  end

  def ssl_grades
    ssl_recheck['endpoints'].map do |endpoint|
      endpoint['grade']
    end
  end

  def lowest_grade
    ssl_grades.sort_by! { |g| GRADE_OPTIONS.index(g) } .reverse![0]
  end

  def run
    grade = lowest_grade
    message "#{config[:domain]} rated #{grade}"
    grade_rank = GRADE_OPTIONS.index(grade)
    if grade_rank > config[:critical]
      critical
    elsif grade_rank > config[:warn]
      warning
    else
      ok
    end
  end
end
