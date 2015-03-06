#!/usr/bin/python -tt
#

# DESCRIPTION:
# Gets uptime and idle time in seconds from /proc/uptime and prints to STDOUT in
# a graphite ready format (plain text protocol), thus meant to be used with a
# graphite metric tcp handler.
#
# OUTPUT:
# Graphite plain-text format (name value timestamp\n)
#
# DEPENDENCIES:
# Python 2.7 (untested on python 3 but should work fine)
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

import logging
import logging.handlers
import optparse
import sys
import time

def set_syslog():
    try:
        logger = logging.getLogger(__name__)
        logger.setLevel(logging.DEBUG)

        formatter = logging.Formatter("%(pathname)s: %(message)s")

        handler = logging.handlers.SysLogHandler(address = '/dev/log')
        handler.setFormatter(formatter)
        logger.addHandler(handler)
    except Exception:
        logging.critical("Failed to configure syslog handler")
        sys.exit(1)
    return logger

def uptime(logger):
    try:
        uptime_file = open('/proc/uptime', 'r')
        uptime_data = uptime_file.read().split()
        uptime_file.close()
    except Exception as e:
        logger.critical(e)
        sys.exit(1)

    up_and_idle_seconds = {}
    up_and_idle_seconds['uptime'] = int(round(float(uptime_data[0])))
    up_and_idle_seconds['idletime'] = int(round(float(uptime_data[1])))

    return up_and_idle_seconds

def print_for_graphite(scheme, metrics, logger):
    now = time.time()
    try:
        for metric in metrics:
            print "%s.%s %d %d" % (scheme, metric, metrics[metric], now)
    except Exception as e:
        logger.critical(e)
        sys.exit(1)

def main():
    parser = optparse.OptionParser()

    parser.add_option('-s', '--scheme',
        default = 'uptime',
        dest    = 'graphite_scheme',
        help    = 'Metric Graphite naming scheme, text to prepend to metric',
        metavar = 'SCHEME')

    (options, args) = parser.parse_args()

    logger = set_syslog()
    metrics = uptime(logger)
    print_for_graphite(options.graphite_scheme, metrics, logger)

if __name__ == '__main__':
    main()
