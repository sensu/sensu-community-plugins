#! /usr/bin/env ruby
#
#   check-couchbase-bucket-quota
#
# DESCRIPTION:
#   This plugin checks Couchbase bucket RAM usage quotas.
#   Based on bucket usage pattern you might want to get alerted then couchbase
#   bucket ram quota is getting close to high watermark and items will get evicted to disk.
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
#   Gem: json
#
# USAGE:
#
# NOTES:
#   This plugin is tested against couchbase 1.8.x
#
# LICENSE:
#   Copyright 2014 Sonian, Inc. and contributors. <support@sensuapp.org>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'rest_client'
require 'json'

class CheckCouchbase < Sensu::Plugin::Check::CLI
  option :user,
         description: 'Couchbase Admin Rest API auth username',
         short: '-u USERNAME',
         long: '--user USERNAME'

  option :password,
         description: 'Couchbase Admin Rest API auth password',
         short: '-P PASSWORD',
         long: '--password PASSWORD'

  option :api,
         description: 'Couchbase Admin Rest API base URL',
         short: '-a URL',
         long: '--api URL',
         default: 'http://localhost:8091'

  option :warn,
         description: 'Warning threshold of bucket ram quota usage',
         short: '-w WARNING',
         long: '--warning WARNING',
         proc: proc(&:to_f),
         default: 70

  option :crit,
         description: 'Critical threshold of bucket ram quota usage',
         short: '-c CRITICAL',
         long: '--critical CRITICAL',
         proc: proc(&:to_f),
         default: 75

  option :bucket,
         description: 'Bucket name, if ommited all buckets will be checked against the thresholds',
         short: '-b BUCKET',
         long: '--bucket BUCKET'

  def run
    begin
      resource = '/pools/default/buckets'
      response = RestClient::Request.new(
        method: :get,
        url: "#{config[:api]}/#{resource}",
        user: config[:user],
        password: config[:password],
        headers: { accept: :json, content_type: :json }
      ).execute
      results = JSON.parse(response.to_str, symbolize_names: true)
    rescue Errno::ECONNREFUSED
      unknown 'Connection refused'
    rescue RestClient::ResourceNotFound
      unknown "Resource not found: #{resource}"
    rescue RestClient::RequestFailed
      unknown 'Request failed'
    rescue RestClient::RequestTimeout
      unknown 'Connection timed out'
    rescue RestClient::Unauthorized
      unknown 'Missing or incorrect Couchbase REST API credentials'
    rescue JSON::ParserError
      unknown 'couchbase REST API returned invalid JSON'
    end

    results.each do |bucket|
      next if config[:bucket] && bucket[:name] != config[:bucket]

      message "Couchbase #{bucket[:name]} bucket quota usage is #{bucket[:basicStats][:quotaPercentUsed]}"
      critical if bucket[:basicStats][:quotaPercentUsed] > config[:crit]
      warning if bucket[:basicStats][:quotaPercentUsed] > config[:warn]
    end

    ok
  end
end
