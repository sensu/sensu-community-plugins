#! /usr/bin/env ruby
#
#   <script name>
#
# DESCRIPTION:
#   what is this thing supposed to do, monitor?  How do alerts or
#   alarms work?
#
# OUTPUT:
#   plain text, metric data, etc
#
# PLATFORMS:
#   Linux, Windows, BSD, Solaris, etc
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: <?>
#
# USAGE:
#   example commands
#
# NOTES:
#   Does it behave differently on specific platforms, specific use cases, etc
#
# LICENSE:
#   <your name>  <your email>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

# !/usr/bin/env ruby
require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'socket'
require 'mail'
require 'json'

class ParseEmail
  def initialize
    @email = ARGF.read
  end

  def token
    @token ||= Mail.read_from_string(@email)
  end

  def body
    return @body if @body
    @body = "#{token.subject}  ERROR BODY:#{token.body} ALERT:#{alert}"
  end

  def service
    return @service if @service
    service_string = token.body.match(/Service: .*/)
    if service_string
      @service = service_string.split(': ')[1]
    else
      @service = token.subject.sub(/([^ ]+) *.*/, '\1')
    end
  end

  def alert
    return @alert if @alert
    alert_string = token.body.match(/Event: .*/)
    if alert_string
      @alert = alert_string.to_s.split(':')[1].strip
    else
      alert_string = token.body.to_s.split("\n")[0]
      @alert = alert_string.split(':')[-1].strip
    end
  end

  def failure?
    array_failure = [
      'Checksum failed',
      'Connection failed',
      'Content failed',
      'Data access error',
      'Execution failed',
      'Filesystem flags failed',
      'GID failed',
      'ICMP failed',
      'Monit instance changed',
      'Invalid type',
      'Does not exist',
      'Permission failed',
      'PID failed',
      'PPID failed',
      'Resource limit matched',
      'Size failed',
      'Status failed',
      'Timeout',
      'Timestamp failed',
      'UID failed',
      'Uptime failed',
      'process is not running.'
    ]
    array_failure.include?(alert)
  end

  def recover?
    array_recovery = [
      /^Checksum succeeded$/,
      /^Connection succeeded$/,
      /^Content succeeded$/,
      /^Data access succeeded$/,
      /^Execution succeeded$/,
      /^Filesystem flags succeeded$/,
      /^GID succeeded$/,
      /^ICMP succeeded$/,
      /^Monit instance changed not$/,
      /^Type succeeded$/,
      /^Exists$/,
      /^Permission succeeded$/,
      /^PID succeeded$/,
      /^PPID succeeded$/,
      /^Resource limit succeeded$/,
      /^Size succeeded$/,
      /^Status succeeded$/,
      /^Timeout recovery$/,
      /^Timestamp succeeded$/,
      /^UID succeeded$/,
      /^Uptime succeeded$/,
      /^process is running with pid \d+.$/
    ]
    !array_recovery.find { |r| alert.match r }.nil?
  end

  def to_json
    { 'output' => body, 'name' => service, 'status' => alert_level, 'type' => 'monit' }.to_json
  end

  def alert_level
    if failure?
      2
    elsif recover?
      0
    else
      3
    end
  end
end

email = ParseEmail.new
s = TCPSocket.new 'localhost', 3030
s.puts email.to_json
s.close
