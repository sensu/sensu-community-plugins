#!/usr/bin/env ruby
#
# Checks that a given Docker container is running
# ===
#
# This is a simple check script for Sensu to check that a Docker container is
# running. You can pass in either a container id or a container name.
#
# EXAMPLES:
#
#   check-docker-container.rb c92d402a5d14
#     CheckDockerContainer OK
#
#   check-docker-container.rb circle_burglar
#     CheckDockerContainer CRITICAL: circle_burglar is not running on the host
#
# OUTPUT:
#    plain-text
#
#     => State.running == true   -> OK
#     => State.running == false  -> CRITICAL
#     => Not Found               -> CRITICAL
#     => Can't connect to Docker -> WARNING
#     => Other exception         -> WARNING
#
# DEPENDENCIES:
#    sensu-plugin Ruby gem
#    docker-api Ruby gem
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'docker'

class CheckDockerContainer < Sensu::Plugin::Check::CLI
  option :url,
         short: '-u DOCKER_HOST',
         long: '--host DOCKER_HOST',
         default: 'tcp://127.0.0.1:4243/'

  def run
    Docker.url = "#{config[:url]}"

    id = argv.first
    container = Docker::Container.get(id)

    if container.info['State']['Running']
      ok
    else
      critical "#{id} is not running"
    end
  rescue Docker::Error::NotFoundError
    critical "#{id} is not running on the host"
  rescue Excon::Errors::SocketError
    warning 'unable to connect to Docker'
  rescue => e
    warning "unknown error #{e.inspect}"
  end
end
