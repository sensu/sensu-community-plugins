#!/usr/bin/env ruby
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details
#
# This handler will execute via mcollective on one or many servers, could be used for example
# to restart a service
# See # See http://imansson.wordpress.com/2012/11/26/why-sensu-is-a-monitoring-router-some-cool-handlers/
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-handler'
require 'net/http'
require 'systemu'

class Resolve < Sensu::Handler
  def mco(application, cmd)
    cmd_line = "mco #{application} #{cmd}"
    run_cmd cmd_line
  end

  def get_scope_parameter(execute)
    scope = execute['scope']
    class_type = execute['class']
    case scope.upcase
    when 'HOST'
      "-I #{@event['client']['address']}"
    when 'CLASS'
      "-C #{class_type}"
    else
      fail "Scope #{scope} is unknown, valid scope is HOST"
    end
  end

  def handle
    # #YELLOW
    unless @event['status'] == 0 # rubocop:disable GuardClause
      executes = @event['check']['execute']
      executes.each do |execute|
        scope_param = get_scope_parameter execute
        mco execute['application'], scope_param + ' ' + execute['execute_cmd']
      end
    end
  end

  def run_cmd(cmd)
    result, stdout, stderr = systemu cmd
    # #YELLOW
    if result != 0 # rubocop:disable GuardClause
      return "Failed to run #{cmd} (exit code #{result}) error is #{stderr.strip}, output is #{stdout.strip}"
    end
  end
end
