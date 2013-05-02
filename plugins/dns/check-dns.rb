#!/usr/bin/env ruby
#
# Checks DNS resolution
# ===
#
# DESCRIPTION:
#   This plugin checks DNS resolution using `dig`.
#
# OUTPUT:
#   plain-text
#
# PLATFORMS:
#   linux
#   bsd
#
# DEPENDENCIES:
#   sensu-plugin Ruby gem
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'

class DNS < Sensu::Plugin::Check::CLI

  option :domain,
    :description => "Domain to resolve",
    :short => '-d DOMAIN',
    :long => '--domain DOMAIN'

  option :type,
    :description => "Record type to resolve (A, AAAA, TXT, etc)",
    :short => '-t RECORD',
    :long => '--type RECORD',
    :default => 'A'

  option :server,
    :description => "Server to use for resolution",
    :short => '-s SERVER',
    :long => '--server SERVER'

  option :result,
    :description => "A positive result entry",
    :short => '-r RESULT',
    :long => '--result RESULT'

  option :warn_only,
    :description => "Warn instead of critical on failure",
    :short => '-w',
    :long => '--warn-only',
    :boolean => true

  option :debug,
    :description => "Print debug information",
    :long => '--debug',
    :boolean => true

  def resolve_domain
    cmd = "dig #{config[:server] ? "@#{config[:server]}" : ""} #{config[:domain]} #{config[:type]} +short +time=1"
    puts cmd if config[:debug]
    output = `#{cmd}`
    puts output if config[:debug]
    # Trim, split, remove comments and empty lines
    entries = output.strip.split("\n").reject{|l| l.match('^;') || l.match('^$')}
    puts "Entries: #{entries}" if config[:debug]
    entries
  end

  def run
    unknown "No domain specified" unless config[:domain]
    entries = resolve_domain
    if entries.length.zero?
      if config[:warn_only]
        warning "Could not resolve #{config[:domain]}"
      else
        critical "Could not resolve #{config[:domain]}"
      end
    else
      if config[:result]
        if entries.include?(config[:result])
          ok "Resolved #{config[:domain]} including #{config[:result]}"
        else
          critical "Resolved #{config[:domain]} did not include #{config[:result]}"
        end
      else
        ok "Resolved #{config[:domain]} #{config[:type]} records"
      end
    end
  end

end
