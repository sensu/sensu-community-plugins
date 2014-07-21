#!/usr/bin/env ruby
# check-beanstalk-statistics.rb
# ===
# Author: S. Zachariah Sprackett <zac@sprackett.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'beanstalk-client'

class CheckBeanstalkStatistic < Sensu::Plugin::Check::CLI
  option :host,
    :short   => '-H HOST',
    :default => 'localhost'
  option :port,
    :short   => '-p PORT',
    :default => '11300'
  option :tube,
    :short   => '-t TUBE'
  option :stat,
    :short   => '-s STAT'
  option :crit_high,
    :short   => '-c CRIT_HIGH_THRESHOLD',
    :proc    => proc { |a| a.to_i },
    :default => false
  option :warn_high,
    :short   => '-w WARN_HIGH_THRESHOLD',
    :proc    => proc { |a| a.to_i },
    :default => false
  option :crit_low,
    :short   => '-C CRIT_LOW_THRESHOLD',
    :proc    => proc { |a| a.to_i },
    :default => 0
  option :warn_low,
    :short   => '-W WARN_LOW_THRESHOLD',
    :proc    => proc { |a| a.to_i },
    :default => 0

  def run
    begin
      beanstalk = Beanstalk::Connection.new(
        "#{config[:host]}:#{config[:port]}"
      )
    rescue Exception => e
      critical "Failed to connect: (#{e})"
    end

    if config[:tube]
      begin
        stats = beanstalk.stats_tube(config[:tube])
      rescue Beanstalk::NotFoundError
        warning "Tube #{config[:tube]} not found"
      end
    else
      stats = beanstalk.stats
    end
    puts config[:stat]
    unknown "#{config[:stat]} doesn't exist" unless stats.has_key?(config[:stat])
    s = stats[config[:stat]].to_i

    if config[:crit_high] && s > config[:crit_high]
      critical "Too many #{config[:stat]} #{config[:crit_high]} (#{s} found)"
    elsif config[:warn_high] && s > config[:warn_high]
      warning "Too many #{config[:stat]} #{config[:warn_high]} jobs (#{s} found)"
    elsif s < config[:crit_low]
      warning "Not enough #{config[:stat]} #{config[:crit_low]} jobs (#{s} found)"
    elsif s < config[:warn_low]
      warning "Not enough #{config[:stat]} #{config[:warn_low]} (#{s} found)"
    else
      ok "#{s} #{config[:stat]} found."
    end
  end
end
