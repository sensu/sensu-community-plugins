#!/usr/bin/env ruby
require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'socket'
require 'mail'
require 'json'

class ParseEmail
  def initialize
    @email = ARGF.read
    @token = Mail.read_from_string(@email)
    alert_string = @token.body.match(/Event: .*/).to_s
    @alert = alert_string.split(':')[1].strip
  end

  def failure?
    array_failure = [
      "Checksum failed",
      "Connection failed",
      "Content failed",
      "Data access error",
      "Execution failed",
      "Filesystem flags failed",
      "GID failed",
      "ICMP failed",
      "Monit instance changed",
      "Invalid type",
      "Does not exist",
      "Permission failed",
      "PID failed",
      "PPID failed",
      "Resource limit matched",
      "Size failed",
      "Status failed",
      "Timeout",
      "Timestamp failed",
      "UID failed",
      "Uptime failed"
    ]
    array_failure.include?(@alert)
  end

  def recover?
    array_recovery = [
      "Checksum succeeded",
      "Connection succeeded",
      "Content succeeded",
      "Data access succeeded",
      "Execution succeeded",
      "Filesystem flags succeeded",
      "GID succeeded",
      "ICMP succeeded",
      "Monit instance changed not",
      "Type succeeded",
      "Exists",
      "Permission succeeded",
      "PID succeeded",
      "PPID succeeded",
      "Resource limit succeeded",
      "Size succeeded",
      "Status succeeded",
      "Timeout recovery",
      "Timestamp succeeded",
      "UID succeeded",
      "Uptime succeeded"
    ]
    array_recovery.include?(@alert)
  end

  def body
    "#{@token.subject}  ERROR BODY:#{@token.body} ALERT:#{@alert}"
  end
  def service
    service_string = @token.body.match(/Service: .*/).to_s
    @service = service_string.split(': ')[1]
  end
end

email = ParseEmail.new

s = TCPSocket.new 'localhost', 3030

if email.failure?
  alert = 2
elsif email.recover?
  alert = 0
else
  alert = 3
end

json = {'output' => email.body, 'name' => email.service, 'status' => alert, 'type' => 'monit'}.to_json

s.puts json
s.close
