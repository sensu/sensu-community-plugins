#!/usr/bin/env ruby
#
# Check Couchbase Plugin
# ===
# 
# DESCRIPTION:
#   This plugin checks Couchbase bucket RAM usage quotas.
#   Based on bucket usage pattern you might want to get alerted then couchbase
#   bucket ram quota is getting close to high watermark and items will get evicted to disk.
#
# COMPATIBILITY:
#   This plugin is tested against couchbase 1.8.x
#
# DEPENDENCIES:
#   sensu-plugin Ruby gem
#   rest-client Ruby gem
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'rest_client'
require 'json'

class CheckCouchbase < Sensu::Plugin::Check::CLI

  option :user,
    :description => 'Couchbase Admin Rest API auth username',
    :short       => '-u USERNAME',
    :long        => '--user USERNAME'

  option :password,
    :description => 'Couchbase Admin Rest API auth password',
    :short       => '-P PASSWORD',
    :long        => '--password PASSWORD'

  option :host,
    :description => 'Couchbase Admin Rest API host',
    :short       => '-h HOSTNAME',
    :long        => '--host HOSTNAME',
    :default     => 'localhost'

  option :port,
    :description => 'Couchbase Admin Rest API port',
    :short       => '-p PORT',
    :long        => '--port PORT',
    :proc        => proc {|a| a.to_i },
    :default     => 8091

  option :warn,
    :description => 'Warning threshold of bucket ram quota usage',
    :short       => '-w WARNING',
    :long        => '--warning WARNING',
    :proc        => proc {|a| a.to_f },
    :default     => 70

  option :crit,
    :description => 'Critical threshold of bucket ram quota usage',
    :short       => '-c CRITICAL',
    :long        => '--critical CRITICAL',
    :proc        => proc {|a| a.to_f },
    :default     => 75

  option :bucket,
    :description => 'Bucket name, if ommited all buckets will be checked against the thresholds',
    :short       => '-b BUCKET',
    :long        => '--bucket BUCKET'

  def run
    response = RestClient::Request.new(
      :method   => :get,
      :url      => "http://#{config[:host]}:#{config[:port]}/pools/default/buckets",
      :user     => config[:user],
      :password => config[:password],
      :headers  => { :accept => :json, :content_type => :json }
    ).execute
    results = JSON.parse(response.to_str, :symbolize_names => true)

    results.each do |bucket|
      next if config[:bucket] && bucket[:name] != config[:bucket]

      message "Couchbase #{bucket[:name]} bucket quota usage is #{bucket[:basicStats][:quotaPercentUsed]}"
      critical if bucket[:basicStats][:quotaPercentUsed] > config[:crit]
      warning if bucket[:basicStats][:quotaPercentUsed] > config[:warn]
    end

    ok
  end
end
