#!/usr/bin/env python
#
# Check OpenStack Neutron Agent Status
# ===
#
# Dependencies
# -----------
# - python-neutronclient and related libraries
#
# Performs API query to determine 'alive' status of all
# (or filtered list of) Neutron network agents. Also has
# ability to warn if any agents have been administratively
# disabled.
#
# Copyright 2013 Brian Clark <brian.clark@cloudapt.com>
#
# Released under the same terms as Sensu (the MIT license);
# see LICENSE for details.
#

# #RED
import sys
import argparse
import logging
from neutronclient.neutron import client

STATE_OK = 0
STATE_WARNING = 1
STATE_CRITICAL = 2
STATE_UNKNOWN = 3

logging.basicConfig(level=logging.INFO)
#logging.basicConfig(level=logging.DEBUG)

parser = argparse.ArgumentParser(description='Check OpenStack Neutron agent status')
parser.add_argument('--auth-url', metavar='URL', type=str,
                    required=True,
                    help='Keystone URL')
parser.add_argument('--username', metavar='username', type=str,
                    required=True,
                    help='username for authentication')
parser.add_argument('--password', metavar='password', type=str,
                    required=True,
                    help='password for authentication')
parser.add_argument('--tenant', metavar='tenant', type=str,
                    required=True,
                    help='tenant name for authentication')
parser.add_argument('--region_name', metavar='region', type=str,
                    help='Region to select for authentication')
parser.add_argument('--host', metavar='host', type=str,
                    help='filter by specific host')
parser.add_argument('--agent-type', metavar='type', type=str,
                    help='filter by specific agent type')
parser.add_argument('--warn-disabled', action='store_true',
                    default=False,
                    help='warn if any agents administratively disabled')
args = parser.parse_args()

try:
    c = client.Client('2.0',
                      username=args.username,
                      tenant_name=args.tenant,
                      password=args.password,
                      auth_url=args.auth_url,
                      region_name=args.region_name)
    params = {}
    if args.host: params['host'] = args.host
    if args.agent_type: params['agent_type'] = args.agent_type
    agents = c.list_agents(**params)
except Exception as e:
    print str(e)
    sys.exit(STATE_CRITICAL)

agents_down = []
agents_disabled = []
messages = []
exit_state = STATE_OK
for a in agents['agents']:
    if a['admin_state_up'] and not a['alive']:
        agents_down.append(a)
    elif not a['admin_state_up']:
        agents_disabled.append(a)

if agents_down:
    for a in agents_down:
        messages.append("{agent_type} on {host} is down".format(agent_type=a['agent_type'], host=a['host']))
        exit_state = STATE_CRITICAL

if args.warn_disabled and agents_disabled:
    for a in agents_disabled:
        messages.append("{agent_type} on {host} is {alive} and disabled"
                        .format(agent_type=a['agent_type'],
                                host=a['host'],
                                alive='alive' if a['alive'] else 'down'))
    if exit_state != STATE_CRITICAL: exit_state = STATE_WARNING

if len(messages) == 1:
     print "Neutron agent status: {status}".format(status=messages[0])
else:
    print "Neutron agent status {agents} total / {agents_down} down / {agents_disabled} disabled".format(agents=len(agents['agents']),
                                                                        agents_down=len(agents_down),
                                                                        agents_disabled=len(agents_disabled))

if len(messages) > 1: print "\n".join(messages)
exit(exit_state)
