#!/usr/bin/env python

# #RED
from argparse import ArgumentParser
import socket
import time

from novaclient.v3 import Client

DEFAULT_SCHEME = '{}.nova.states'.format(socket.gethostname())

def output_metric(name, value):
    print '{}\t{}\t{}'.format(name, value, int(time.time()))

def main():
    parser = ArgumentParser()
    parser.add_argument('-u', '--user', default='admin')
    parser.add_argument('-p', '--password', default='admin')
    parser.add_argument('-t', '--tenant', default='admin')
    parser.add_argument('-a', '--auth-url', default='http://localhost:5000/v2.0')
    parser.add_argument('-S', '--service-type', default='compute')
    parser.add_argument('-s', '--scheme', default=DEFAULT_SCHEME)
    args = parser.parse_args()

    client = Client(args.user, args.password, args.tenant, args.auth_url, service_type=args.service_type)

    servers = client.servers.list()

    # http://docs.openstack.org/api/openstack-compute/2/content/List_Servers-d1e2078.html
    states = {
        'ACTIVE': 0,
        'BUILD': 0,
        'DELETED': 0,
        'ERROR': 0,
        'HARD_REBOOT': 0,
        'PASSWORD': 0,
        'REBOOT': 0,
        'REBUILD': 0,
        'RESCUE': 0,
        'RESIZE': 0,
        'REVERT_RESIZE': 0,
        'SHUTOFF': 0,
        'SUSPENDED': 0,
        'UNKNOWN': 0,
        'VERIFY_RESIZE': 0,
    }

    for server in servers:
        if server.status not in states:
            states[server.status] = 0

        states[server.status] += 1

    for state, count in states.iteritems():
        output_metric('{}.{}'.format(args.scheme, state.lower()), count)

if __name__ == '__main__':
    main()
