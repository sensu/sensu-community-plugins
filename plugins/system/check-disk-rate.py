#!/usr/bin/python
# Try to estimate the time at which we will run out of disk space
# based on day-over-day usage and make some noise if it looks like
# we have <48h before we run out.  Should run ONCE A DAY.  
# filesystem_history: '/mnt/: capacity
import psutil
import gdbm
import time
import sys

ESTIMATING_INTERVAL = 2
GDBM_LOCATION = "/tmp/.check-disk-trend.gdbm"

def get_gdbm_db():
  db = gdbm.open(GDBM_LOCATION, 'c')
  return db

def grok_df():
  ret = {}
  for partition in psutil.disk_partitions():
    capacity = psutil.disk_usage(partition[0][0]).percent
    ret[partition[0][0]] = capacity

  return ret

def main():
  errors = False
  filesystem_history = get_gdbm_db()
  filesystem_now = grok_df()

  for filesystem in filesystem_now:
    if filesystem in filesystem_history:
      rate = filesystem_now[filesystem] - float(filesystem_history[filesystem])
      if rate > 0:
        if ((100 - filesystem_now[filesystem]) - (rate * ESTIMATING_INTERVAL)) < 10:
          print "CRIT: filesystem %s will be critical within %d day(s) (presently at %s used, writing %s/day)" % (filesystem, ESTIMATING_INTERVAL, filesystem_now[filesystem], rate)
          errors = True
    filesystem_history[str(filesystem)] = str(filesystem_now[filesystem])
        
  filesystem_history.close()

  if not errors:
    print "OK: Looks good."
    sys.exit(0)
  sys.exit(1)

main()
