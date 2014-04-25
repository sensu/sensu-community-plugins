#!/usr/bin/env ruby
# check-beanstalk-watchers-to-buried.rb
# ===
# Author: S. Zachariah Sprackett <zac@sprackett.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'beanstalk-client'

class CheckBeanstalkWatchersToBuried < Sensu::Plugin::Check::CLI
  option :host,
    :short   => '-H HOST',
    :default => 'localhost'
  option :port,
    :short   => '-p PORT',
    :default => '11300'
  option :tube,
    :short   => '-t TUBE'
  option :crit,
    :short   => '-c CRIT_THRESHOLD',
    :proc    => proc { |a| a.to_i },
    :default => 0
  option :warn,
    :short   => '-w WARN_THRESHOLD',
    :proc    => proc { |a| a.to_i },
    :default => 0

  def run
    unknown "Tube was not set" unless config[:tube]
    begin
      beanstalk = Beanstalk::Connection.new(
        "#{config[:host]}:#{config[:port]}"
      )
    rescue Exception => e
      critical "Failed to connect: (#{e})"
    end

    begin
      stats = beanstalk.stats_tube(config[:tube])
      watchers = stats['current-watching'].to_i
      buried = stats['current-jobs-buried'].to_i
    rescue Beanstalk::NotFoundError
      warning "Tube #{config[:tube]} not found"
    end
    unless watchers
      watchers = 0
    end

    if config[:crit] || (buried-watchers) > config[:crit]
      critical "Exceeded buried jobs by threshold of #{config[:crit]} (#{watchers}/#{buried})"
    elsif config[:warn] || (buried - watchers) > config[:warn]
      warning "Exceeded buried jobs by threshold of #{config[:warn]} (#{watchers}/#{buried})"
    else
      ok "#{buried} buried jobs and #{watchers} watchers found."
    end
  end
end
