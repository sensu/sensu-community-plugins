#!/usr/bin/python -tt
#
# DESCRIPTION:
# Collect everything that can be collected out of jstat (shells out 5 times)
# and spits to STDOUT in a graphite ready format, thus meant to be used with a
# graphite metric tcp handler.
# Since it shells out to jps(1) you will need the user running the sensu client
# executing this script to be able to run jps as the same user running the JVM
# you are trying to get stats from.
# In addition it will also need to be able to run jstat(2) against the JVM
# This can be all achieved by allowing the script to be ran as the same user
# running the JVM, for instance by prepending "sudo -u <jvm_process_owner>"
# in the command check definition (with the proper sudoers config to allow this
# with no password being asked)
#
# The graphite node is composed of an optional root node (defaults to 'metrics')
# the specified FQDN "reversed" ('foo.bar.com' becomes 'com.bar.foo') and an
# optional scheme (defaults to 'jstat')
#
# (1) http://docs.oracle.com/javase/7/docs/technotes/tools/share/jps.html
# (2) http://docs.oracle.com/javase/7/docs/technotes/tools/share/jstat.html
#
# OUTPUT:
# Graphite plain-text format (name value timestamp\n)
#
# DEPENDENCIES:
# Python 2.7 (untested on python 3 but should work fine)
# Java 6 (untested on Java 7 but should work fine)
#
#
# Released under the same terms as Sensu (the MIT license); see LICENSE
# for details.

import logging
import logging.handlers
import optparse
from subprocess import check_output
import sys
import time

class JstatMetricsToGraphiteFormat(object):
  '''Prints jstat metrics to stdout in graphite format

  Shells out to run jstat using the JVM id found via jps (also shelled out) and
  passed argument to print to STDOUT (for use with sensu) the metrics value.
  Jstat column titles are replaced with more explanatory names. Requires to be
  ran as a user that can get the JVM id via jps and run jstat on that JVM'''

  def main(self):
    # Setting up logging to syslog
    try:
      logger = logging.getLogger(__name__)
      logger.setLevel(logging.DEBUG)

      formatter = logging.Formatter("%(pathname)s: %(message)s")

      handler = logging.handlers.SysLogHandler(address = '/dev/log')
      handler.setFormatter(formatter)
      logger.addHandler(handler)
    except Exception:
      # booting is more important than logging
      logging.critical("Failed to configure syslog handler")

    parser = optparse.OptionParser()

    parser.add_option('-g', '--graphite-base',
      default = 'metrics',
      dest    = 'graphite_base',
      help    = 'The base graphite node',
      metavar = 'NODE')

    parser.add_option('-D', '--debug',
      action  = 'store_true',
      default = False,
      dest    = 'debug',
      help    = 'Debug output (NOISY!)')

    parser.add_option('-H', '--host',
      default = None,
      dest    = 'hostname',
      help    = 'The name of the host to run jstat on',
      metavar = 'HOST')

    parser.add_option('-j', '--java-name',
      default = None,
      dest    = 'java_app_name',
      help    = 'The name of the Java app to call jstat on',
      metavar = 'JAVANAME')

    parser.add_option('-s', '--scheme',
      default = 'jstat',
      dest    = 'service',
      help    = 'Metric naming scheme, text to prepend to metric',
      metavar = 'SERVICE')

    (options, args) = parser.parse_args()

    if not options.java_app_name:
      parser.error('A Java app name is required')

    if not options.hostname:
      parser.error('A host name is required')

    # Replace jstat colums titles with more explicit ones
    # Stats coming from -gc
    metric_maps_gc = { "S0C": "current_survivor_space_0_capacity_KB",
                       "S1C": "current_survivor_space_1_capacity_KB",
                       "S0U": "survivor_space_0_utilization_KB",
                       "S1U": "survivor_space_1_utilization_KB",
                       "EC": "current_eden_space_capacity_KB",
                       "EU": "eden_space_utilization_KB",
                       "OC": "current_old_space_capacity_KB",
                       "OU": "old_space_utilization_KB",
                       "PC": "current_permanent_space_capacity_KB",
                       "PU": "permanent_space_utilization_KB",
                       "YGC": "number_of_young_generation_GC_events",
                       "YGCT": "young_generation_garbage_collection_time",
                       "FGC": "number_of_stop_the_world_events",
                       "FGCT": "full_garbage_collection_time",
                       "GCT": "total_garbage_collection_time"
                       }

    # Stats coming from -gccapacity
    metric_maps_gccapacity = { "NGCMN": "minimum_size_of_new_area",
                               "NGCMX": "maximum_size_of_new_area",
                               "NGC": "current_size_of_new_area",
                               "OGCMN": "minimum_size_of_old_area",
                               "OGCMX": "maximum_size_of_old_area",
                               "OGC": "current_size_of_old_area",
                               "PGCMN": "minimum_size_of_permanent_area",
                               "PGCMX": "maximum_size_of_permanent_area",
                               "PGC": "current_size_of_permanent_area",
                               "PC": "current_size_of_permanent_area"
                               }

    # Stats coming from -gcnew
    metric_maps_gcnew = { "TT" : "tenuring_threshold",
                          "MTT": "maximum_tenuring_threshold",
                          "DSS": "adequate_size_of_survivor"
                           }

    # Stats coming from -compiler
    metric_maps_compiler = {
        "Compiled": "compilation_tasks_performed",
        "Failed": "compilation_tasks_failed",
        "Invalid": "compilation_tasks_invalidated",
        "Time": "time_spent_on_compilation_tasks"
        }

    # Stats coming from -class
    ## Note that since "Bytes" appears twice in jstat -class output we need
    ## to differentiate them by colum number
    metric_maps_class = {
        "Loaded": "loaded_classes",
        "Bytes_column2": "loaded_KB",
        "Unloaded": "unloaded_classes",
        "Bytes_column4": "unloaded_KB",
        "Time": "time_spent_on_class_load_unload"
        }

    def get_jstat_metrics(jstat_option, lvmid, metric_maps):
      '''Runs jstat with provided option on provided host, returns mapped stats'''
      def is_number(s):
        '''returns true if string is a number'''
        try:
          float(s)
          return True
        except ValueError:
          pass
        try:
          import unicodedata
          unicodedata.numeric(s)
          return True
        except (TypeError, ValueError):
          pass
        return False

      # Get stats from jstat stdout
      try :
        jstat_gc_out = check_output(["jstat", jstat_option, lvmid])
      except Exception as e:
        if options.debug:
          print e
          sys.exit(1)
        logger.critical(e)
        sys.exit(1)

      values_all = jstat_gc_out.split("\n")[1].split()
      # Remove non number strings
      values = [ jstat_val for jstat_val in values_all if is_number(jstat_val) ]
      # Transform float strings to integers
      values = map(int, map(float, values))

      # Change stats titles to long names
      titles = jstat_gc_out.split("\n")[0].split()
      # Deal with -class special "double Bytes" output
      if jstat_option == "-class":
       titles[2] = "Bytes_column2"
       titles[4] = "Bytes_column4"
      metrics_long =[]
      for title in titles:
        for short_title in metric_maps:
          if title == short_title:
            metrics_long.append(metric_maps[short_title])

      stats = dict(zip(metrics_long, values))
      return stats

    # Get lvmid (JVM id)
    try :
      jps_out = check_output(["jps"])
    except Exception as e:
      if options.debug:
        print e
        sys.exit(1)
      logger.critical(e)
      sys.exit(1)

    lvmid = False
    for line in jps_out.split("\n"):
      if options.java_app_name in line:
        lvmid = line.split()[0]

    if not lvmid:
      if options.debug:
        print "Could not get an LVM id"
        sys.exit(1)
      logger.critical("Could not get an LVM id")
      sys.exit(1)

    # Get stats from -gc
    gc_stats = get_jstat_metrics("-gc", lvmid, metric_maps_gc)
    if options.debug:
      print gc_stats
    # Get stats from -gccapacity
    gccapacity_stats = get_jstat_metrics("-gccapacity",
        lvmid, metric_maps_gccapacity)
    if options.debug:
      print gccapacity_stats
    # Get stats from -gcnew
    gcnew_stats = get_jstat_metrics("-gcnew", lvmid, metric_maps_gcnew)
    if options.debug:
      print gccapacity_stats

    # Put all GC related stats to the same dict
    gc_stats.update(gccapacity_stats)
    gc_stats.update(gcnew_stats)

    # Get stats from -compiler
    compiler_stats = get_jstat_metrics("-compiler", lvmid, metric_maps_compiler)
    if options.debug:
      print compiler_stats

    # Get stats from -class
    class_stats = get_jstat_metrics("-class", lvmid, metric_maps_class)
    if options.debug:
      print class_stats

    # Print to stdout in graphite format
    now = time.time()
    graphite_base = '.'.join([options.graphite_base,
        '.'.join(reversed(options.hostname.split('.')))])

    for metric in gc_stats:
      print "%s.%s.jvm.gc.%s %s %d" % (graphite_base, options.service, metric,
          gc_stats[metric], now)

    for metric in compiler_stats:
      print "%s.%s.jvm.compiler.%s %s %d" % (graphite_base, options.service,
          metric, compiler_stats[metric], now)

    for metric in class_stats:
      print "%s.%s.jvm.class.%s %s %d" % (graphite_base, options.service,
          metric, class_stats[metric], now)

if '__main__' == __name__:
  JstatMetricsToGraphiteFormat().main()
