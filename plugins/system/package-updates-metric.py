#!/usr/bin/env python
#coding=utf-8

#   package-updates-metric.py
#
# DESCRIPTION:
# package-updates-metric is used to check avaliable package updates
# for Debian or Ubuntu system.
# The script is inspired by /usr/lib/update-notifier/apt_check.py
#
# OUTPUT:
#   JSON-formatted text
#
# PLATFORMS:
#   Debian, Ubuntu
#
# DEPENDENCIES:
# Python APT Library
#
# LICENSE:
#   Huang Yaming <yumminhuang@gmail.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

import apt
import apt_pkg
import json
import os
import subprocess
import sys


SYNAPTIC_PINFILE = "/var/lib/synaptic/preferences"
DISTRO = subprocess.check_output(["lsb_release", "-c", "-s"],
                                 universal_newlines=True).strip()

# The packages in BLACKLIST WON'T be checked.
BLACKLIST = ['linux-virtual', 'linux-image-virtual', 'linux-headers-virtual',]


def clean(cache,depcache):
    """ unmark (clean) all changes from the given depcache """
    # mvo: looping is too inefficient with the new auto-mark code
    # for pkg in cache.Packages:
    #    depcache.MarkKeep(pkg)
    depcache.init()


def saveDistUpgrade(cache,depcache):
    """ this functions mimics a upgrade but will never remove anything """
    depcache.upgrade(True)
    if depcache.del_count > 0:
        clean(cache,depcache)
    depcache.upgrade()


def isSecurityUpgrade(ver):
    """ check if the given version is a security update (or masks one) """
    security_pockets = [("Ubuntu", "%s-security" % DISTRO),
                        ("gNewSense", "%s-security" % DISTRO),
                        ("Debian", "%s-updates" % DISTRO)]

    for (file, index) in ver.file_list:
        for origin, archive in security_pockets:
            if (file.archive == archive and file.origin == origin):
                return True
    return False


def get_update_packages():
    """
    Return a list of dict about package updates
    """
    pkgs = []

    apt_pkg.init()
    # force apt to build its caches in memory for now to make sure
    # that there is no race when the pkgcache file gets re-generated
    apt_pkg.config.set("Dir::Cache::pkgcache","")

    try:
        cache = apt_pkg.Cache(apt.progress.base.OpProgress())
    except SystemError as e:
        sys.stderr.write("Error: Opening the cache (%s)" % e)
        sys.exit(-1)

    depcache = apt_pkg.DepCache(cache)
    # read the pin files
    depcache.read_pinfile()
    # read the synaptic pins too
    if os.path.exists(SYNAPTIC_PINFILE):
        depcache.read_pinfile(SYNAPTIC_PINFILE)
    # init the depcache
    depcache.init()

    try:
        saveDistUpgrade(cache,depcache)
    except SystemError as e:
        sys.stderr.write("Error: Marking the upgrade (%s)" % e)
        sys.exit(-1)

    for pkg in cache.packages:
        if not (depcache.marked_install(pkg) or depcache.marked_upgrade(pkg)):
            continue
        inst_ver = pkg.current_ver
        cand_ver = depcache.get_candidate_ver(pkg)
        if cand_ver == inst_ver:
            # Package does not have available update
            continue
        if not inst_ver or not cand_ver:
            # Some packages are not installed(i.e. linux-headers-3.2.0-77)
            # skip these updates
            continue
        if pkg.name in BLACKLIST:
            # skip the package in blacklist
            continue
        record = {"name": pkg.name,
                  "security": isSecurityUpgrade(cand_ver),
                  "current_version": inst_ver.ver_str,
                  "candidate_version": cand_ver.ver_str}
        pkgs.append(record)

    return pkgs


def package_check_metric():
    """
    Print output and exit status as Sensu required.
    OK       0: no updates
    WARNING  1: available normal updates
    CRITICAL 2: available security updates
    UNKNOWN  3: exceptions or errors
    """
    try:
        pkgs = get_update_packages()
        security_pkgs = filter(lambda p: p.get('security'), pkgs)
    except Exception as e:
        # Catch all unknown exceptions
        print str(e)
        sys.exit(3)

    if not pkgs:
        # No available update
        print json.dumps(pkgs)
        sys.exit(0)
    elif not security_pkgs:
        # Has available updates
        print json.dumps(pkgs)
        sys.exit(1)
    else:
        # Has available security updates
        print json.dumps(pkgs)
        sys.exit(2)

if __name__ == '__main__':
    package_check_metric()
