#!/usr/bin/env ruby
#
# Push docker stats into graphite
# ===
#
# DESCRIPTION:
#   This plugin gets the stats data provided by docker API
#   and sends it to graphite.
#
#
# DEPENDENCIES:
#   sensu-plugin   Ruby gem
#   socket         Ruby stdlib
#   pathname       Ruby stdlib
#   sys/proctable  Ruby stdlib
#
# EXAMPLE:
# docker.hostname.e3f35c891c409fb57d2bd09135ccdfc8ca560a845e9d42f8313c1619160f6a00.supervisord.rss	3485	1407488861
# docker.hostname.e3f35c891c409fb57d2bd09135ccdfc8ca560a845e9d42f8313c1619160f6a00.supervisord.vsize	53399552	1407488861
# docker.hostname.e3f35c891c409fb57d2bd09135ccdfc8ca560a845e9d42f8313c1619160f6a00.supervisord.nswap	0	1407488861
# docker.hostname.e3f35c891c409fb57d2bd09135ccdfc8ca560a845e9d42f8313c1619160f6a00.supervisord.pctmem	0.05	1407488861
# docker.hostname.e3f35c891c409fb57d2bd09135ccdfc8ca560a845e9d42f8313c1619160f6a00.supervisord.fd	20	1407488861
# docker.hostname.e3f35c891c409fb57d2bd09135ccdfc8ca560a845e9d42f8313c1619160f6a00.supervisord.cpu	1	1407488861
# docker.hostname.e3f35c891c409fb57d2bd09135ccdfc8ca560a845e9d42f8313c1619160f6a00.cron.rss	269	1407488861
# docker.hostname.e3f35c891c409fb57d2bd09135ccdfc8ca560a845e9d42f8313c1619160f6a00.cron.vsize	24223744	1407488861
# docker.hostname.e3f35c891c409fb57d2bd09135ccdfc8ca560a845e9d42f8313c1619160f6a00.cron.nswap	0	1407488861
# docker.hostname.e3f35c891c409fb57d2bd09135ccdfc8ca560a845e9d42f8313c1619160f6a00.cron.pctmem	0.0	1407488861
# docker.hostname.e3f35c891c409fb57d2bd09135ccdfc8ca560a845e9d42f8313c1619160f6a00.cron.fd	4	1407488861
# docker.hostname.e3f35c891c409fb57d2bd09135ccdfc8ca560a845e9d42f8313c1619160f6a00.cron.cpu	0	1407488861
#
# LICENSE
# Copyright 2014 Michal Cichra. Github @mikz
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'socket'
require 'pathname'
require 'sys/proctable'

class DockerContainerMetrics < Sensu::Plugin::Metric::CLI::Graphite

  option :scheme,
         :description => 'Metric naming scheme, text to prepend to metric',
         :short => '-s SCHEME',
         :long => '--scheme SCHEME',
         :default => "docker.#{Socket.gethostname}"

  option :cgroup_path,
         :description => 'path to cgroup mountpoint',
         :short => '-c PATH',
         :long => '--cgroup PATH',
         :default => '/sys/fs/cgroup'

  option :docker_host,
         description: 'docker host',
         short: '-H DOCKER_HOST',
         long: '--docker-host DOCKER_HOST',
         default: 'tcp://127.0.1.1:4243'

  def run
    container_metrics
    ok
  end

  def container_metrics
    cgroup = Pathname(config[:cgroup_path]).join('cpu/docker')

    timestamp = Time.now.to_i
    ps = Sys::ProcTable.ps.group_by(&:pid)
    sleep(1)
    ps2 = Sys::ProcTable.ps.group_by(&:pid)

    fields = [:rss, :vsize, :nswap, :pctmem]

    ENV['DOCKER_HOST'] = config[:docker_host]
    containers = `docker ps --quiet --no-trunc`.split("\n")

    containers.each do |container|
      pids = cgroup.join(container).join('cgroup.procs').readlines.map(&:to_i)

      processes = ps.values_at(*pids).flatten.compact.group_by(&:comm)
      processes2 = ps2.values_at(*pids).flatten.compact.group_by(&:comm)

      processes.each do |comm, process|
        prefix = "#{config[:scheme]}.#{container}.#{comm}"
        fields.each do |field|
          output "#{prefix}.#{field}", process.map(&field).reduce(:+), timestamp
        end
        # this check requires a lot of permissions, even root maybe?
        output "#{prefix}.fd", process.map { |p| p.fd.keys.count }.reduce(:+), timestamp

        second = processes2[comm]
        cpu = second.map { |p| p.utime + p.stime }.reduce(:+) - process.map { |p| p.utime + p.stime }.reduce(:+)
        output "#{prefix}.cpu", cpu, timestamp
      end
    end
  end
end
