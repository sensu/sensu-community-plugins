#! /usr/bin/env ruby
#
# check-ses-limit
#
# DESCRIPTION:
#   Gets your SES sending limit and issues a warn and critical based on percentages
#   you supply for your daily sending limit
#   Checks how close you are getting in percentages to your 24 hour ses sending limit
#
# OUTPUT:
#   plain-text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: aws-sdk
#   gem: sensu-plugin
#
# USAGE:
#   #YELLOW
#
# NOTES:
#
# LICENSE:
#   Copyright (c) 2014, Joel <jjshoe@gmail.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'aws/ses'

class CheckSESLimit < Sensu::Plugin::Check::CLI
  option :aws_access_key,
         short: '-a AWS_ACCESS_KEY',
         long: '--aws-access-key AWS_ACCESS_KEY',
         description: "AWS Access Key. Either set ENV['AWS_ACCESS_KEY_ID'] or provide it as an option",
         required: true

  option :aws_secret_access_key,
         short: '-s AWS_SECRET_ACCESS_KEY',
         long: '--aws-secret-access-key AWS_SECRET_ACCESS_KEY',
         description: "AWS Secret Access Key. Either set ENV['AWS_SECRET_ACCESS_KEY'] or provide it as an option",
         required: true

  option :warn_percent,
         short: '-W WARN_PERCENT',
         long: '--warn_perc WARN_PERCENT',
         description: 'Warn when the percentage of mail sent is at or above this number',
         default: 75,
         proc: proc(&:to_i)

  option :crit_percent,
         short: '-C CRIT_PERCENT',
         long: '--crit_perc CRIT_PERCENT',
         description: 'Critical when the percentage of mail sent is at or above this number',
         default: 90,
         proc: proc(&:to_i)

  def run
    begin
      ses = AWS::SES::Base.new(
        access_key_id: config[:aws_access_key],
        secret_access_key: config[:aws_secret_access_key])

      response = ses.quota
    rescue AWS::SES::ResponseError => e
      critical "An issue occured while communicating with the AWS SES API: #{e.message}"
    end

    # #YELLOW
    unless response.empty? # rubocop:disable GuardClause
      percent = (response.sent_last_24_hours.to_i / response.max_24_hour_send.to_i) * 100
      message = "SES sending limit is at #{percent}%"

      if config[:crit_percent] > 0 && config[:crit_percent] <= percent
        critical message
      elsif config[:warn_percent] > 0 && config[:warn_percent] <= percent
        warning message
      else
        ok message
      end
    end
  end
end
