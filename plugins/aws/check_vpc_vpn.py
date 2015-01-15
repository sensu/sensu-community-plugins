#!/usr/bin/python

# #RED
import argparse
import boto.ec2
from boto.vpc import VPCConnection
import sys


def main():
    try:
        conn = boto.vpc.VPCConnection(aws_access_key_id=args.aws_access_key_id, aws_secret_access_key=args.aws_secret_access_key, region=boto.ec2.get_region(args.region))
    except:
        print "UNKNOWN: Unable to connect to reqion %s" % args.region
        sys.exit(3)

    errors = []
    for vpn_connection in conn.get_all_vpn_connections():
        for tunnel in vpn_connection.tunnels:
            if tunnel.status != 'UP':
                errors.append("[gateway: %s connection: %s tunnel: %s status: %s]" % (vpn_connection.vpn_gateway_id, vpn_connection.id, tunnel.outside_ip_address, tunnel.status))

    if len(errors) > 1:
        print 'CRITICAL: ' + ' '.join(errors)
        sys.exit(2)
    elif len(errors) > 0:
        print 'WARN: ' + ' '.join(errors)
        sys.exit(1)
    else:
        print 'OK'
        sys.exit(0)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Check status of all existing AWS VPC VPN Tunnels')

    parser.add_argument('-a', '--aws-access-key-id', required=True, dest='aws_access_key_id', help='AWS Access Key')
    parser.add_argument('-s', '--aws-secret-access-key', required=True, dest='aws_secret_access_key', help='AWS Secret Access Key')
    parser.add_argument('-r', '--region', required=True, dest='region', help='AWS Region')

    args = parser.parse_args()

    main()
