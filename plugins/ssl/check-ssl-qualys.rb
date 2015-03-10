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
#   gem: httparty
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
require 'httparty'

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

  def ssl_info
    r = HTTParty.get("#{config[:api_url]}analyze?host=#{config[:domain]}")
    check_status = r['status']
    if check_status == 'ERROR'
      critical "ERROR on #{config[:domain]} check"
    elsif check_status != 'READY'
      warning "#{config[:domain]} check not READY"
    end
    r
  end

  def ssl_grades
    ssl_info['endpoints'].map do |endpoint|
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
