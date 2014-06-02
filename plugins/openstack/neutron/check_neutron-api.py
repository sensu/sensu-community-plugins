#!/usr/bin/env python
#
# Check OpenStack Neutron API Status
# ===
#
# Dependencies
# -----------
# - python-neutronclient and related libraries
#
# Performs API query to determine 'alive' status of the
# Neutron API.
#
# Author: Mike Dorman <mdorman@godaddy.com>
# Significantly based on neutron-agent-status.py by
# Brian Clark <brian.clark@cloudapt.com>
#
# Released under the same terms as Sensu (the MIT license);
# see LICENSE for details.
#

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

parser = argparse.ArgumentParser(description='Check OpenStack Neutron API status')
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
parser.add_argument('--bypass', metavar='bybass', type=str,
                    required=False,
                    help='bypass the service catalog and use this URL for Nova API')

args = parser.parse_args()

try:
    c = client.Client('2.0',
                      username=args.username,
                      tenant_name=args.tenant,
                      password=args.password,
                      auth_url=args.auth_url,
                      region_name=args.region_name,
                      insecure=True,
                      endpoint_url=args.bypass)
    networks = c.list_networks()
except Exception as e:
    print str(e)
    sys.exit(STATE_CRITICAL)

if len(networks) < 1:
  exit_state = STATE_WARNING
  state_string = "WARNING"
else:
  exit_state = STATE_OK
  state_string = "OK"

print "Neutron API status: {state_str}, {networks} network(s) found.".format(state_str=state_string, networks=len(networks))
sys.exit(exit_state)
