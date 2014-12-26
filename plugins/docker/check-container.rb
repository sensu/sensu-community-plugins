#! /usr/bin/env ruby
#
#   check-container
#
# DESCRIPTION:
#   This is a simple check script for Sensu to check that a Docker container is
#   running. You can pass in either a container id or a container name.
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: docker
#
# USAGE:
#   check-docker-container.rb c92d402a5d14
#   CheckDockerContainer OK
#
#   check-docker-container.rb circle_burglar
#   CheckDockerContainer CRITICAL: circle_burglar is not running on the host
#
# NOTES:
#     => State.running == true   -> OK
#     => State.running == false  -> CRITICAL
#     => Not Found               -> CRITICAL
#     => Can't connect to Docker -> WARNING
#     => Other exception         -> WARNING
#
# LICENSE:
#   Copyright 2014 Sonian, Inc. and contributors. <support@sensuapp.org>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
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
