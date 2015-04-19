#! /usr/bin/env ruby
# encoding: UTF-8
#   sidekiq-metrics
#
# DESCRIPTION:
#   Pull sidekiq metrics from a sidekiq-monitor-stats enabled endpoint.
#
#     https://github.com/harvesthq/sidekiq-monitor-stats
#
# OUTPUT:
#   metric data
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

require 'sensu-plugin/metric/cli'
require 'open-uri'
require 'json'

class SidekiqMetrics < Sensu::Plugin::Metric::CLI::Graphite
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

  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         default: 'sidekiq'

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
      unknown "Could not load sidekiq stats from #{config[:url]}. Error: #{error}"
    end

    total_concurrency = stats['processes'].map { |process| process['concurrency'] }.reduce(&:+) || 0
    total_busy        = stats['processes'].map { |process| process['busy'] }.reduce(&:+) || 0
    maximum_latency   = stats['queues'].map { |name, data| data['latency'] }.max

    output "#{config[:scheme]}.concurrency", total_concurrency
    output "#{config[:scheme]}.busy",        total_busy
    output "#{config[:scheme]}.latency",     maximum_latency

    ok
  end
end
