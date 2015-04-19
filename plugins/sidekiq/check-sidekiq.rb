#! /usr/bin/env ruby
# encoding: UTF-8
#   check-sidekiq
#
# DESCRIPTION:
#   Check sidekiq status from a sidekiq-monitor-stats enabled endpoint.
#
#     https://github.com/harvesthq/sidekiq-monitor-stats
#
#   Uses the maximum latency to check the status.
#
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: open-uri
#   gem: json
#
# LICENSE:
#   Albert Llop albert@getharvest.com
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'

require 'sensu-plugin/check/cli'
require 'open-uri'
require 'json'

class SidekiqCheck < Sensu::Plugin::Check::CLI
  option :url,
         short: '-u URL',
         long: '--url URL',
         description: 'Url to query',
         required: true

  option :auth,
         short: '-a USER:PASSWORD',
         long: '--auth USER:PASSWORD',
         description: 'Basic auth credentials if you need them',
         proc: proc { |auth| auth.split(':') }

  option :warn,
         short: '-w SECONDS',
         long: '--warn SECONDS',
         description: 'Warn after job has been SECONDS seconds in a queue',
         proc: proc { |seconds| seconds.to_i },
         default: 120

  option :crit,
         short: '-c SECONDS',
         long: '--crit SECONDS',
         description: 'Critical after job has been SECONDS seconds in a queue',
         proc: proc { |seconds| seconds.to_i },
         default: 300

  def run
    begin
      stats = JSON.parse(
        if config[:auth]
          open(config[:url], http_basic_authentication: config[:auth]).read
        else
          open(config[:url]).read
        end
      )

    rescue => error
      unknown "Could not load Sidekiq stats from #{config[:url]}. Error: #{error}"
    end

    maximum_latency   = stats['queues'].map { |name, data| data['latency'] }.max
    total_concurrency = stats['processes'].map { |process| process['concurrency'] }.reduce(&:+) || 0

    if total_concurrency.zero?
      critical 'There are no Sidekiq workers'
    end

    if maximum_latency > config[:warn]
      warning "A job has been in a queue longer than #{config[:warn]} seconds"
    elsif maximum_latency > config[:crit]
      critical "A job has been in a queue longer than #{config[:crit]} seconds"
    end

    ok "Maximum job latency #{maximum_latency}"
  end
end
