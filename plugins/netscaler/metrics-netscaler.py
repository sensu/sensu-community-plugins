#!/usr/bin/python -tt
#
# DESCRIPTION:
# Grabs stats from a netscaler appliance via the Nitro REST API.
# Prints to STDOUT in graphite format thus meant for a TCP handler
# To find out what each stat means download the Nitro SDK
# http://support.citrix.com/proddocs/topic/netscaler-main-api-10-map/ns-nitro-rest-feat-stat-api-ref.html
# You should also be able to get the stats docs in a PDF that can be downloaded
# from your netscaler web UI.
#
# OUTPUT:
# Graphite plain-text format (name value timestamp\n)
#
# DEPENDENCIES:
# Python 2.7 (untested on python 3 but should work fine)
# Python Requests (http://docs.python-requests.org)
#
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.
import logging
import logging.handlers
import optparse
import requests
import sys
import time

FLAT_STATS_ENDPOINTS = [
    'ns',
    'cmp',
    'ssl',
    'system'
    ]

STATS_WITH_IDS = [
    {
      'endpoint' : 'lbvserver',
      'identifier' : 'name'
      },
    {
      'endpoint' : 'Interface',
      'identifier' : 'id'
      }
    ]


FAILURE_CONSTANT = 1

def set_syslog():
  '''Set a syslog logger'''
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

def isfloat(value):
  try:
    float(value)
    return True
  except ValueError:
    return False

def graphite_printer(stats, graphite_scheme):
  now = time.time()
  for stat in stats:
    print "%s.%s %s %d" % (graphite_scheme, stat, stats[stat], now)

def get_flat_stats(flat_stats_end_points, nitro_version, netscaler, user,
    password, logger):
  nitro_rest_api = 'http://%s/nitro/%s/stat/' % (netscaler, nitro_version)
  flat_stats = {}
  for flat_stat_end_point in flat_stats_end_points:
    url = nitro_rest_api + flat_stat_end_point
    try:
      response = requests.get(url, auth=(user, password))
    except Exception as e:
      logger.critical('Could not get JSON from %s' % url)
      logger.critical(e)
      sys.exit(FAILURE_CONSTANT)
    data = response.json()
    for flat_stat in data[flat_stat_end_point]:
      value = data[flat_stat_end_point][flat_stat]
      if isfloat(value):
        flat_stats[flat_stat_end_point+ '.' + flat_stat] = value
  return flat_stats

def get_stats_with_ids(stat_with_ids_end_point, stat_identifier, nitro_version,
    netscaler, user, password, logger):
  nitro_rest_api = 'http://%s/nitro/%s/stat/' % (netscaler, nitro_version)
  url = nitro_rest_api + stat_with_ids_end_point
  stats_with_ids = {}
  try:
    response = requests.get(url, auth=(user, password))
  except Exception as e:
    logger.critical('Could not get JSON from %s' % url)
    logger.critical(e)
    sys.exit(FAILURE_CONSTANT)
  data = response.json()
  for stats in data[stat_with_ids_end_point]:
    stat_id = stats[stat_identifier]
    stat_id_alnum = ''.join(e for e in stat_id if e.isalnum())
    for stat in stats:
      value = stats[stat]
      if isfloat(value):
        stat_name = stat_with_ids_end_point + '.' + stat_id_alnum + '.' + stat
        stats_with_ids[stat_name] = value
  return stats_with_ids


def main():
  parser = optparse.OptionParser()

  parser.add_option('-n', '--netscaler',
    help    = 'netscaler (IP or FQDN) to collect stats from',
    dest    = 'netscaler',
    metavar = 'netscaler')

  parser.add_option('-u', '--user',
    help    = 'netscaler user with access to nitro rest',
    dest    = 'user',
    metavar = 'USER')

  parser.add_option('-p', '--password',
    help    = 'netscaler user password',
    dest    = 'password',
    metavar = 'PASSWORD')

  parser.add_option('-s', '--graphite_scheme',
    help    = 'graphite scheme to prepend, default to <netscaler>',
    default = 'netscaler',
    dest    = 'graphite_scheme',
    metavar = 'GRAPHITE_SCHEME')

  parser.add_option('-v', '--nitro-version',
    help    = 'nitro REST API version, defaults to v1',
    default = 'v1',
    dest    = 'nitro_version',
    metavar = 'NITRO_VERSION')

  (options, args) = parser.parse_args()

  if not options.netscaler or not options.user or not options.password:
    print 'A netscaler, user and password are required'
    sys.exit(FAILURE_CONSTANT)
 
  nitro_version = options.nitro_version
  netscaler = options.netscaler
  user = options.user
  password = options.password

  logger = set_syslog()

  flat_stats = get_flat_stats(FLAT_STATS_ENDPOINTS, nitro_version, netscaler, user,
      password, logger)
  graphite_printer(flat_stats, options.graphite_scheme)

  for stat_with_ids in STATS_WITH_IDS:
    stats_with_ids = get_stats_with_ids(stat_with_ids['endpoint'],
        stat_with_ids['identifier'], nitro_version, netscaler, user, password,
        logger)
    graphite_printer(stats_with_ids, options.graphite_scheme)


if __name__ == '__main__':
  main()
