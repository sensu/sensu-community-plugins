#! /usr/bin/env ruby
#
# check-beanstalkd
#
# DESCRIPTION:
#  Check beanstalkd queues

# OUTPUT:
#   plain-text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: beaneater
#   gem: json
#   gem: sensu-plugin
#
# USAGE:
#   #YELLOW
#
# NOTES:
#
# LICENSE:
#   Copyright 2014 99designs, Inc <devops@99designs.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'json'
require 'beaneater'

# Checks the queue levels
class BeanstalkdQueuesStatus < Sensu::Plugin::Check::CLI
  check_name 'beanstalkd queues check'

  option :tube,
         short:       '-t name',
         long:        '--tube name',
         description: 'Name of the tube to check',
         default:     'default'

  option :server,
         description: 'beanstalkd server',
         short:       '-s SERVER',
         long:        '--server SERVER',
         default:     'localhost'

  option :port,
         description: 'beanstalkd server port',
         short:       '-p PORT',
         long:        '--port PORT',
         default:     '11300'

  option :ready,
         description: 'ready tasks WARNING/CRITICAL thresholds',
         short:       '-r W,C',
         long:        '--ready-tasks W,C',
         proc:        proc { |a| a.split(',', 2).map(&:to_i) },
         default:     [6000, 8000]

  option :urgent,
         description: 'urgent tasks WARNING/CRITICAL thresholds',
         short:       '-u W,C',
         long:        '--urgent-tasks W,C',
         proc:        proc { |a| a.split(',', 2).map(&:to_i) },
         default:     [2000, 3000]

  option :buried,
         description: 'buried tasks WARNING/CRITICAL thresholds',
         short:       '-b W,C',
         long:        '--buried-tasks W,C',
         proc:        proc { |a| a.split(',', 2).map(&:to_i) },
         default:     [30, 60]

  def acquire_beanstalkd_connection
    begin
      conn = Beaneater::Pool.new(["#{config[:server]}:#{config[:port]}"])
    rescue
      warning 'could not connect to beanstalkd'
    end
    conn
  end

  def run
    stats = acquire_beanstalkd_connection.tubes["#{config[:tube]}"].stats
    message 'All queues are healthy'

    warns, crits, msg = check_queues(stats)
    msg.join("\n")

    if crits.size > 0
      message msg
      critical
    end

    if warns.size > 0
      message msg
      warning
    end
    ok
  end

  def check_queues(stats)
    msg = []
    crits = {}
    warns = {}

    [:ready, :urgent, :buried].each do |task|
      tasks = stats.send("current_jobs_#{task}".to_sym)

      if tasks > config[task][1]
        crits[task] = tasks
        msg << task.to_s + " queue has #{tasks} items"
        next
      end

      if tasks > config[task][0]
        warns[task] = tasks
        msg << task.to_s + " queue has #{tasks} items"
      end
    end

    [warns, crits, msg]
  end
end
