#!/usr/bin/env ruby

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'socket'
require 'json'

class JbossThreads < Sensu::Plugin::Metric::CLI

    option :scheme,
        :short => "-s SCHEME",
        :long => "--scheme SCHEME",
        :description => "Metric naming scheme. Prepended to ...",
        :default => "#{Socket.gethostname}.disk_usage"

    option :jboss,
        :short => "-j JBOSS_HOME",
        :long => "--jboss JBOSS_HOME",
        :description => "Location of the JBoss directory. The /bin folder in this dir must contain the jboss_cli.sh"

    option :url,
        :short => "-u JBOSS_URL",
        :long => "--url JBOSS_URL",
        :description => "URL of the JBoss instance to connect to. Format: {host}:{port}. Default: localhost:9999"
        :default => "localhost:9999"

    def get_thread_stats(jboss_home, url)
        script = "%s/bin/jboss-cli.sh" % jboss_home
        jboss_cli_cmds = "\"connect %s,cd core-service=platform-mbean/type=threading,:read-resource(recursive=true)\"" % url 
        full_cmd = "./%s --commands=%s" % [script, jboss_cli_cmds]
        all_thread_stats = `#{full_cmd}`
        return all_thread_stats

    def jboss_format_to_json(jboss_cli_output)
        arrow_replace = jboss_cli_output.gsub(/\s=>/, ':')
        long_replace = jboss_cli_o
