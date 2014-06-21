#!/usr/bin/env ruby
#
# Generic check raising an error if exit code of command is not N.
# ===
#
# Jean-Francois Theroux <failshell@gmail.com>
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'

class CheckCMDStatus < Sensu::Plugin::Check::CLI

  option :command,
    :description => 'command to run (might need quotes)',
    :short => '-c',
    :long => '--command COMMAND',
    :required => true

  option :status,
    :description => 'exit status code the check should get',
    :short => '-s',
    :long => '--status STATUS',
    :default => '0'

  option :check_output,
    :description => 'Optionally check the process stdout against a regex',
    :short => '-o',
    :long => '--check_output REGEX'

  def get_cmd_status
    stdout = `#{config[:command]}`
    unless $?.exitstatus.to_s == config[:status]
      critical "#{config[:command]} exited with #{$?.exitstatus}"
    else
      if config[:check_output]
        if Regexp.new(config[:check_output]).match(stdout)
          ok "#{config[:command]} matched #{config[:check_output]} and exited with #{$?.exitstatus}"
        else
          critical "#{config[:command]} output didn't match #{config[:check_output]} (exit #{$?.exitstatus})"
        end
      else
        ok "#{config[:command]} exited with #{$?.exitstatus}"
      end
    end
  end

  def run
    get_cmd_status
  end

end
