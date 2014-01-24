#!/usr/bin/env ruby
# check-beanstalk-jobs.rb
# ===
# Author: S. Zachariah Sprackett <zac@sprackett.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'beanstalk-client'

class CheckBeanstalkWorkers < Sensu::Plugin::Check::CLI
  option :host,
    :short   => '-H HOST',
    :default => 'localhost'
  option :port,
    :short   => '-p PORT',
    :default => '11300'
  option :tube,
    :short   => '-t TUBE'
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
    jobs = stats['current-jobs-ready'] + stats['current-jobs-delayed']

    if config[:crit_high] && jobs > config[:crit_high]
      critical "High threshold is #{config[:crit_high]} jobs (#{jobs} active jobs)"
    elsif config[:warn_high] && jobs > config[:warn_high]
      warning "High threshold is #{config[:warn_high]} jobs (#{jobs} active jobs)"
    elsif jobs < config[:crit_low]
      warning "Low threshold is #{config[:crit_low]} jobs (#{jobs} active jobs)"
    elsif jobs < config[:warn_low]
      warning "Low threshold is #{config[:warn_low]} (#{jobs} active jobs)"
    else
      ok "#{jobs} jobs found."
    end
  end
end
