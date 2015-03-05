#!/usr/bin/env ruby
#
#   ldap-metrics.rb
#
# AUTHOR
#   Matt Ford
#    - matt@dancingfrog.co.uk
#    - matt@bashton.com
#
# DESCRIPTION
#   This plugin uses the LDAP cn=monitor database to generate
#   output suitable for graphite
#
#   It requires that the monitoring module is loaded and that a monitoring
#   database has been set up.
#
#   ldapmodify the following:
#   dn: cn=module{0},cn=config
#   changetype: modify
#   add: olcModuleLoad
#   olcModuleLoad: back_monitor
#
#   ldapadd the following:
#   dn: olcDatabase=Monitor,cn=config
#   objectClass: olcDatabaseConfig
#   objectClass: olcMonitorConfig
#   olcDatabase: Monitor
#   olcAccess: to dn.subtree="cn=Monitor" by dn.base="cn=suitable,dc=user" read by * none
#
# LICENSE:
#   Copyright (c) 2014, Bashton Ltd
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/metric/cli'
require 'sensu-plugin/utils'
require 'socket'
require 'net/ldap'

include Sensu::Plugin::Utils

class LDAPGraphite < Sensu::Plugin::Metric::CLI::Graphite
  option :scheme,
         description: 'Metric naming scheme, text to prepend to metric',
         short: '-s SCHEME',
         long: '--scheme SCHEME',
         default: "#{Socket.gethostname}.ldap_metrics"

  option :host,
         short: '-h HOST',
         long: '--host HOST',
         description: 'Host',
         default: 'localhost'

  option :port,
         short: '-t PORT',
         long: '--port PORT',
         description: 'Port to connect to OpenLDAP on',
         default: 389,
         proc: proc(&:to_i)

  option :base,
         short: '-b BASE',
         long: '--base BASE',
         description: 'Base',
         default: 'cn=Monitor'

  option :user,
         short: '-u USER',
         long: '--user USER',
         description: 'User to bind as',
         required: true

  option :password,
         short: '-p PASSWORD',
         long: '--password PASSWORD',
         description: 'Password used to bind',
         required: true

  option :insecure,
         short: '-i',
         long: '--insecure',
         description: 'Do not use encryption'

  def get_metrics(host)
    ldap = Net::LDAP.new host: host,
                         port: config[:port],
                         auth: {
                           method: :simple,
                           username: config[:user],
                           password: config[:password]
                         }

    unless config[:insecure]
      ldap.encryption(method: :simple_tls)
    end

    begin
      if ldap.bind
        message += 'So far'
        metrics = {
          conn_total: {
            title: 'connections.total',
            search: 'cn=Total,cn=Connections',
            attribute: 'monitorCounter'
          },
          conn_cur: {
            title: 'connections.current',
            search: 'cn=Current,cn=Connections',
            attribute: 'monitorCounter'
          },
          stats_bytes: {
            title: 'statistics.bytes',
            search: 'cn=Bytes,cn=Statistics',
            attribute: 'monitorCounter'
          },
          stats_PDU: {
            title: 'statistics.pdu',
            search: 'cn=PDU,cn=Statistics',
            attribute: 'monitorCounter'
          },
          stats_entries: {
            title: 'statistics.entries',
            search: 'cn=Entries,cn=Statistics',
            attribute: 'monitorCounter'
          },
          stats_referrals: {
            title: 'statistics.referrals',
            search: 'cn=Referrals,cn=Statistics',
            attribute: 'monitorCounter'
          }
        }
        monitor_ops = %w(add modify delete search compare bind unbind)
        %w(initiated completed).each do |state|
          monitor_ops.each do |op|
            metrics["ops_#{op}_#{state}".to_sym] = {
              title: "operations.#{op}.#{state}",
              search: "cn=#{op},cn=Operations",
              attribute: "monitorOp#{state}"
            }
          end
        end
        metrics.each do |_key, metric|
          ldap.search(base: "#{metric[:search]},#{config[:base]}",
                      attributes: [metric[:attribute]],
                      return_result: true,
                      scope: Net::LDAP::SearchScope_BaseObject) do |entry|
            metric[:value] = entry[metric[:attribute]]
          end
        end
        return metrics
      else
        message = "Cannot connect to #{host}:#{config[:port]}"
        if config[:user]
          message += " as #{config[:user]}"
        end
        critical message
      end
    end
  rescue
    message = "Cannot connect to #{host}:#{config[:port]}"
    message += " as #{config[:user]}"
    critical message
  end

  def run
    get_metrics(config[:host]).each do |_key, metric|
      output [config[:scheme], metric[:title]].join('.'), metric[:value]
    end
    ok
  end
end
