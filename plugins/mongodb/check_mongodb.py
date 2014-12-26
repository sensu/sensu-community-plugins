#!/usr/bin/env python

#
# A MongoDB Nagios check script
#

# Script idea taken from a Tag1 script I found and I modified it a lot
#
# Main Author
#   - Mike Zupan <mike@zcentric.com>
# Contributers
#   - Frank Brandewiede <brande@travel-iq.com> <brande@bfiw.de> <brande@novolab.de>
#   - Sam Perman <sam@brightcove.com>
#   - Shlomo Priymak <shlomoid@gmail.com>
#   - @jhoff909 on github
#   - @jbraeuer on github
#   - Dag Stockstad <dag.stockstad@gmail.com>
#   - @Andor on github
#   - Steven Richards - Captainkrtek on Github <sbrichards@mit.edu>
#

# License: BSD
# Copyright (c) 2012, Mike Zupan <mike@zcentric.com>
# All rights reserved.
# Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
#
# Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
# Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the
# documentation and/or other materials provided with the distribution.
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
# THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS
# BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
# GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
# STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# README: https://github.com/mzupan/nagios-plugin-mongodb/blob/master/LICENSE

# #RED
import sys
import time
import optparse
import textwrap
import re
import os

try:
    import pymongo
except ImportError, e:
    print e
    sys.exit(2)

# As of pymongo v 1.9 the SON API is part of the BSON package, therefore attempt
# to import from there and fall back to pymongo in cases of older pymongo
if pymongo.version >= "1.9":
    import bson.son as son
else:
    import pymongo.son as son


#
# thanks to http://stackoverflow.com/a/1229667/72987
#
def optional_arg(arg_default):
    def func(option, opt_str, value, parser):
        if parser.rargs and not parser.rargs[0].startswith('-'):
            val = parser.rargs[0]
            parser.rargs.pop(0)
        else:
            val = arg_default
        setattr(parser.values, option.dest, val)
    return func


def performance_data(perf_data, params):
    data = ''
    if perf_data:
        data = " |"
        for p in params:
            p += (None, None, None, None)
            param, param_name, warning, critical = p[0:4]
            data += "%s=%s" % (param_name, str(param))
            if warning or critical:
                warning = warning or 0
                critical = critical or 0
                data += ";%s;%s" % (warning, critical)

            data += " "

    return data


def numeric_type(param):
    if ((type(param) == float or type(param) == int or param == None)):
        return True
    return False


def check_levels(param, warning, critical, message, ok=[]):
    if (numeric_type(critical) and numeric_type(warning)):
        if param >= critical:
            print "CRITICAL - " + message
            sys.exit(2)
        elif param >= warning:
            print "WARNING - " + message
            sys.exit(1)
        else:
            print "OK - " + message
            sys.exit(0)
    else:
        if param in critical:
            print "CRITICAL - " + message
            sys.exit(2)

        if param in warning:
            print "WARNING - " + message
            sys.exit(1)

        if param in ok:
            print "OK - " + message
            sys.exit(0)

        # unexpected param value
        print "CRITICAL - Unexpected value : %d" % param + "; " + message
        return 2


def get_server_status(con):
    try:
        set_read_preference(con.admin)
        data = con.admin.command(pymongo.son_manipulator.SON([('serverStatus', 1)]))
    except:
        data = con.admin.command(son.SON([('serverStatus', 1)]))
    return data


def main(argv):
    p = optparse.OptionParser(conflict_handler="resolve", description="This Nagios plugin checks the health of mongodb.")

    p.add_option('-H', '--host', action='store', type='string', dest='host', default='127.0.0.1', help='The hostname you want to connect to')
    p.add_option('-P', '--port', action='store', type='int', dest='port', default=27017, help='The port mongodb is runnung on')
    p.add_option('-u', '--user', action='store', type='string', dest='user', default=None, help='The username you want to login as')
    p.add_option('-p', '--pass', action='store', type='string', dest='passwd', default=None, help='The password you want to use for that user')
    p.add_option('-W', '--warning', action='store', dest='warning', default=None, help='The warning threshold we want to set')
    p.add_option('-C', '--critical', action='store', dest='critical', default=None, help='The critical threshold we want to set')
    p.add_option('-A', '--action', action='store', type='choice', dest='action', default='connect', help='The action you want to take',
                 choices=['connect', 'connections', 'replication_lag', 'replication_lag_percent', 'replset_state', 'memory', 'memory_mapped', 'lock',
                          'flushing', 'last_flush_time', 'index_miss_ratio', 'databases', 'collections', 'database_size', 'database_indexes', 'collection_indexes', 'collection_size',
                          'queues', 'oplog', 'journal_commits_in_wl', 'write_data_files', 'journaled', 'opcounters', 'current_lock', 'replica_primary', 'page_faults',
                          'asserts', 'queries_per_second', 'page_faults', 'chunks_balance', 'connect_primary', 'collection_state', 'row_count', 'replset_quorum'])
    p.add_option('--max-lag', action='store_true', dest='max_lag', default=False, help='Get max replication lag (for replication_lag action only)')
    p.add_option('--mapped-memory', action='store_true', dest='mapped_memory', default=False, help='Get mapped memory instead of resident (if resident memory can not be read)')
    p.add_option('-D', '--perf-data', action='store_true', dest='perf_data', default=False, help='Enable output of Nagios performance data')
    p.add_option('-d', '--database', action='store', dest='database', default='admin', help='Specify the database to check')
    p.add_option('--all-databases', action='store_true', dest='all_databases', default=False, help='Check all databases (action database_size)')
    p.add_option('-s', '--ssl', dest='ssl', default=False, action='callback', callback=optional_arg(True), help='Connect using SSL')
    p.add_option('-r', '--replicaset', dest='replicaset', default=None, action='callback', callback=optional_arg(True), help='Connect to replicaset')
    p.add_option('-q', '--querytype', action='store', dest='query_type', default='query', help='The query type to check [query|insert|update|delete|getmore|command] from queries_per_second')
    p.add_option('-c', '--collection', action='store', dest='collection', default='admin', help='Specify the collection to check')
    p.add_option('-T', '--time', action='store', type='int', dest='sample_time', default=1, help='Time used to sample number of pages faults')

    options, arguments = p.parse_args()
    host = options.host
    port = options.port
    user = options.user
    passwd = options.passwd
    query_type = options.query_type
    collection = options.collection
    sample_time = options.sample_time
    if (options.action == 'replset_state'):
        warning = str(options.warning or "")
        critical = str(options.critical or "")
    else:
        warning = float(options.warning or 0)
        critical = float(options.critical or 0)

    action = options.action
    perf_data = options.perf_data
    max_lag = options.max_lag
    database = options.database
    ssl = options.ssl
    replicaset = options.replicaset

    if action == 'replica_primary' and replicaset is None:
        return "replicaset must be passed in when using replica_primary check"
    elif not action == 'replica_primary' and replicaset:
        return "passing a replicaset while not checking replica_primary does not work"

    #
    # moving the login up here and passing in the connection
    #
    start = time.time()
    err, con = mongo_connect(host, port, ssl, user, passwd, replicaset)
    if err != 0:
        return err

    conn_time = time.time() - start
    conn_time = round(conn_time, 0)

    if action == "connections":
        return check_connections(con, warning, critical, perf_data)
    elif action == "replication_lag":
        return check_rep_lag(con, host, port, warning, critical, False, perf_data, max_lag, user, passwd)
    elif action == "replication_lag_percent":
        return check_rep_lag(con, host, port, warning, critical, True, perf_data, max_lag, user, passwd)
    elif action == "replset_state":
        return check_replset_state(con, perf_data, warning, critical)
    elif action == "memory":
        return check_memory(con, warning, critical, perf_data, options.mapped_memory)
    elif action == "memory_mapped":
        return check_memory_mapped(con, warning, critical, perf_data)
    elif action == "queues":
        return check_queues(con, warning, critical, perf_data)
    elif action == "lock":
        return check_lock(con, warning, critical, perf_data)
    elif action == "current_lock":
        return check_current_lock(con, host, warning, critical, perf_data)
    elif action == "flushing":
        return check_flushing(con, warning, critical, True, perf_data)
    elif action == "last_flush_time":
        return check_flushing(con, warning, critical, False, perf_data)
    elif action == "index_miss_ratio":
        index_miss_ratio(con, warning, critical, perf_data)
    elif action == "databases":
        return check_databases(con, warning, critical, perf_data)
    elif action == "collections":
        return check_collections(con, warning, critical, perf_data)
    elif action == "oplog":
        return check_oplog(con, warning, critical, perf_data)
    elif action == "journal_commits_in_wl":
        return check_journal_commits_in_wl(con, warning, critical, perf_data)
    elif action == "database_size":
        if options.all_databases:
            return check_all_databases_size(con, warning, critical, perf_data)
        else:
            return check_database_size(con, database, warning, critical, perf_data)
    elif action == "database_indexes":
        return check_database_indexes(con, database, warning, critical, perf_data)
    elif action == "collection_indexes":
        return check_collection_indexes(con, database, collection, warning, critical, perf_data)
    elif action == "collection_size":
        return check_collection_size(con, database, collection, warning, critical, perf_data)
    elif action == "journaled":
        return check_journaled(con, warning, critical, perf_data)
    elif action == "write_data_files":
        return check_write_to_datafiles(con, warning, critical, perf_data)
    elif action == "opcounters":
        return check_opcounters(con, host, warning, critical, perf_data)
    elif action == "asserts":
        return check_asserts(con, host, warning, critical, perf_data)
    elif action == "replica_primary":
        return check_replica_primary(con, host, warning, critical, perf_data, replicaset)
    elif action == "queries_per_second":
        return check_queries_per_second(con, query_type, warning, critical, perf_data)
    elif action == "page_faults":
        check_page_faults(con, sample_time, warning, critical, perf_data)
    elif action == "chunks_balance":
        chunks_balance(con, database, collection, warning, critical)
    elif action == "connect_primary":
        return check_connect_primary(con, warning, critical, perf_data)
    elif action == "collection_state":
        return check_collection_state(con, database, collection)
    elif action == "row_count":
        return check_row_count(con, database, collection, warning, critical, perf_data)
    elif action == "replset_quorum":
        return check_replset_quorum(con, perf_data)
    else:
        return check_connect(host, port, warning, critical, perf_data, user, passwd, conn_time)


def mongo_connect(host=None, port=None, ssl=False, user=None, passwd=None, replica=None):
    try:
        # ssl connection for pymongo > 2.3
        if pymongo.version >= "2.3":
            if replica is None:
                con = pymongo.MongoClient(host, port)
            else:
                con = pymongo.Connection(host, port, read_preference=pymongo.ReadPreference.SECONDARY, ssl=ssl, replicaSet=replica, network_timeout=10)
        else:
            if replica is None:
                con = pymongo.Connection(host, port, slave_okay=True, network_timeout=10)
            else:
                con = pymongo.Connection(host, port, slave_okay=True, network_timeout=10)
                #con = pymongo.Connection(host, port, slave_okay=True, replicaSet=replica, network_timeout=10)

        if user and passwd:
            db = con["admin"]
            if not db.authenticate(user, passwd):
                sys.exit("Username/Password incorrect")
    except Exception, e:
        if isinstance(e, pymongo.errors.AutoReconnect) and str(e).find(" is an arbiter") != -1:
            # We got a pymongo AutoReconnect exception that tells us we connected to an Arbiter Server
            # This means: Arbiter is reachable and can answer requests/votes - this is all we need to know from an arbiter
            print "OK - State: 7 (Arbiter)"
            sys.exit(0)
        return exit_with_general_critical(e), None
    return 0, con


def exit_with_general_warning(e):
    if isinstance(e, SystemExit):
        return e
    else:
        print "WARNING - General MongoDB warning:", e
    return 1


def exit_with_general_critical(e):
    if isinstance(e, SystemExit):
        return e
    else:
        print "CRITICAL - General MongoDB Error:", e
    return 2


def set_read_preference(db):
    if pymongo.version >= "2.1":
        db.read_preference = pymongo.ReadPreference.SECONDARY


def check_connect(host, port, warning, critical, perf_data, user, passwd, conn_time):
    warning = warning or 3
    critical = critical or 6
    message = "Connection took %i seconds" % conn_time
    message += performance_data(perf_data, [(conn_time, "connection_time", warning, critical)])

    return check_levels(conn_time, warning, critical, message)


def check_connections(con, warning, critical, perf_data):
    warning = warning or 80
    critical = critical or 95
    try:
        data = get_server_status(con)

        current = float(data['connections']['current'])
        available = float(data['connections']['available'])

        used_percent = int(float(current / (available + current)) * 100)
        message = "%i percent (%i of %i connections) used" % (used_percent, current, current + available)
        message += performance_data(perf_data, [(used_percent, "used_percent", warning, critical),
                (current, "current_connections"),
                (available, "available_connections")])
        return check_levels(used_percent, warning, critical, message)

    except Exception, e:
        return exit_with_general_critical(e)


def check_rep_lag(con, host, port, warning, critical, percent, perf_data, max_lag, user, passwd):
    # Get mongo to tell us replica set member name when connecting locally
    if "127.0.0.1" == host:
        host = con.admin.command("ismaster","1")["me"].split(':')[0]

    if percent:
        warning = warning or 50
        critical = critical or 75
    else:
        warning = warning or 600
        critical = critical or 3600
    rs_status = {}
    slaveDelays = {}
    try:
        set_read_preference(con.admin)

        # Get replica set status
        try:
            rs_status = con.admin.command("replSetGetStatus")
        except pymongo.errors.OperationFailure, e:
            if e.code == None and str(e).find('failed: not running with --replSet"'):
                print "OK - Not running with replSet"
                return 0

        serverVersion = tuple(con.server_info()['version'].split('.'))
        if serverVersion >= tuple("2.0.0".split(".")):
            #
            # check for version greater then 2.0
            #
            rs_conf = con.local.system.replset.find_one()
            for member in rs_conf['members']:
                if member.get('slaveDelay') is not None:
                    slaveDelays[member['host']] = member.get('slaveDelay')
                else:
                    slaveDelays[member['host']] = 0

            # Find the primary and/or the current node
            primary_node = None
            host_node = None

            for member in rs_status["members"]:
                if member["stateStr"] == "PRIMARY":
                    primary_node = member
                if member["name"].split(':')[0] == host and int(member["name"].split(':')[1]) == port:
                    host_node = member

            # Check if we're in the middle of an election and don't have a primary
            if primary_node is None:
                print "WARNING - No primary defined. In an election?"
                return 1

            # Check if we failed to find the current host
            # below should never happen
            if host_node is None:
                print "CRITICAL - Unable to find host '" + host + "' in replica set."
                return 2

            # Is the specified host the primary?
            if host_node["stateStr"] == "PRIMARY":
                if max_lag == False:
                    print "OK - This is the primary."
                    return 0
                else:
                    #get the maximal replication lag
                    data = ""
                    maximal_lag = 0
                    for member in rs_status['members']:
                        if not member['stateStr'] == "ARBITER":
                            lastSlaveOpTime = member['optimeDate']
                            replicationLag = abs(primary_node["optimeDate"] - lastSlaveOpTime).seconds - slaveDelays[member['name']]
                            data = data + member['name'] + " lag=%d;" % replicationLag
                            maximal_lag = max(maximal_lag, replicationLag)
                    if percent:
                        err, con = mongo_connect(primary_node['name'].split(':')[0], int(primary_node['name'].split(':')[1]), False, user, passwd)
                        if err != 0:
                            return err
                        primary_timediff = replication_get_time_diff(con)
                        maximal_lag = int(float(maximal_lag) / float(primary_timediff) * 100)
                        message = "Maximal lag is " + str(maximal_lag) + " percents"
                        message += performance_data(perf_data, [(maximal_lag, "replication_lag_percent", warning, critical)])
                    else:
                        message = "Maximal lag is " + str(maximal_lag) + " seconds"
                        message += performance_data(perf_data, [(maximal_lag, "replication_lag", warning, critical)])
                    return check_levels(maximal_lag, warning, critical, message)
            elif host_node["stateStr"] == "ARBITER":
                print "OK - This is an arbiter"
                return 0

            # Find the difference in optime between current node and PRIMARY

            optime_lag = abs(primary_node["optimeDate"] - host_node["optimeDate"])

            if host_node['name'] in slaveDelays:
                slave_delay = slaveDelays[host_node['name']]
            elif host_node['name'].endswith(':27017') and host_node['name'][:-len(":27017")] in slaveDelays:
                slave_delay = slaveDelays[host_node['name'][:-len(":27017")]]
            else:
                raise Exception("Unable to determine slave delay for {0}".format(host_node['name']))

            try:  # work starting from python2.7
                lag = optime_lag.total_seconds()
            except:
                lag = float(optime_lag.seconds + optime_lag.days * 24 * 3600)

            if percent:
                err, con = mongo_connect(primary_node['name'].split(':')[0], int(primary_node['name'].split(':')[1]), False, user, passwd)
                if err != 0:
                    return err
                primary_timediff = replication_get_time_diff(con)
                if primary_timediff != 0:
                    lag = int(float(lag) / float(primary_timediff) * 100)
                else:
                    lag = 0
                message = "Lag is " + str(lag) + " percents"
                message += performance_data(perf_data, [(lag, "replication_lag_percent", warning, critical)])
            else:
                message = "Lag is " + str(lag) + " seconds"
                message += performance_data(perf_data, [(lag, "replication_lag", warning, critical)])
            return check_levels(lag, warning + slaveDelays[host_node['name']], critical + slaveDelays[host_node['name']], message)
        else:
            #
            # less than 2.0 check
            #
            # Get replica set status
            rs_status = con.admin.command("replSetGetStatus")

            # Find the primary and/or the current node
            primary_node = None
            host_node = None
            for member in rs_status["members"]:
                if member["stateStr"] == "PRIMARY":
                    primary_node = (member["name"], member["optimeDate"])
                if member["name"].split(":")[0].startswith(host):
                    host_node = member

            # Check if we're in the middle of an election and don't have a primary
            if primary_node is None:
                print "WARNING - No primary defined. In an election?"
                sys.exit(1)

            # Is the specified host the primary?
            if host_node["stateStr"] == "PRIMARY":
                print "OK - This is the primary."
                sys.exit(0)

            # Find the difference in optime between current node and PRIMARY
            optime_lag = abs(primary_node[1] - host_node["optimeDate"])
            lag = optime_lag.seconds
            if percent:
                err, con = mongo_connect(primary_node['name'].split(':')[0], int(primary_node['name'].split(':')[1]))
                if err != 0:
                    return err
                primary_timediff = replication_get_time_diff(con)
                lag = int(float(lag) / float(primary_timediff) * 100)
                message = "Lag is " + str(lag) + " percents"
                message += performance_data(perf_data, [(lag, "replication_lag_percent", warning, critical)])
            else:
                message = "Lag is " + str(lag) + " seconds"
                message += performance_data(perf_data, [(lag, "replication_lag", warning, critical)])
            return check_levels(lag, warning, critical, message)

    except Exception, e:
        return exit_with_general_critical(e)


def check_memory(con, warning, critical, perf_data, mapped_memory):
    #
    # These thresholds are basically meaningless, and must be customized to your system's ram
    #
    warning = warning or 8
    critical = critical or 16
    try:
        data = get_server_status(con)
        if not data['mem']['supported'] and not mapped_memory:
            print "OK - Platform not supported for memory info"
            return 0
        #
        # convert to gigs
        #
        message = "Memory Usage:"
        try:
            mem_resident = float(data['mem']['resident']) / 1024.0
            message += " %.2fGB resident," % (mem_resident)
        except:
            mem_resident = 0
            message += " resident unsupported,"
        try:
            mem_virtual = float(data['mem']['virtual']) / 1024.0
            message += " %.2fGB virtual," % mem_virtual
        except:
            mem_virtual = 0
            message += " virtual unsupported,"
        try:
            mem_mapped = float(data['mem']['mapped']) / 1024.0
            message += " %.2fGB mapped," % mem_mapped
        except:
            mem_mapped = 0
            message += " mapped unsupported,"
        try:
            mem_mapped_journal = float(data['mem']['mappedWithJournal']) / 1024.0
            message += " %.2fGB mappedWithJournal" % mem_mapped_journal
        except:
            mem_mapped_journal = 0
        message += performance_data(perf_data, [("%.2f" % mem_resident, "memory_usage", warning, critical),
                    ("%.2f" % mem_mapped, "memory_mapped"), ("%.2f" % mem_virtual, "memory_virtual"), ("%.2f" % mem_mapped_journal, "mappedWithJournal")])
        #added for unsupported systems like Solaris
        if mapped_memory and mem_resident == 0:
            return check_levels(mem_mapped, warning, critical, message)
        else:
            return check_levels(mem_resident, warning, critical, message)

    except Exception, e:
        return exit_with_general_critical(e)


def check_memory_mapped(con, warning, critical, perf_data):
    #
    # These thresholds are basically meaningless, and must be customized to your application
    #
    warning = warning or 8
    critical = critical or 16
    try:
        data = get_server_status(con)
        if not data['mem']['supported']:
            print "OK - Platform not supported for memory info"
            return 0
        #
        # convert to gigs
        #
        message = "Memory Usage:"
        try:
            mem_mapped = float(data['mem']['mapped']) / 1024.0
            message += " %.2fGB mapped," % mem_mapped
        except:
            mem_mapped = -1
            message += " mapped unsupported,"
        try:
            mem_mapped_journal = float(data['mem']['mappedWithJournal']) / 1024.0
            message += " %.2fGB mappedWithJournal" % mem_mapped_journal
        except:
            mem_mapped_journal = 0
        message += performance_data(perf_data, [("%.2f" % mem_mapped, "memory_mapped"), ("%.2f" % mem_mapped_journal, "mappedWithJournal")])

        if not mem_mapped == -1:
            return check_levels(mem_mapped, warning, critical, message)
        else:
            print "OK - Server does not provide mem.mapped info"
            return 0

    except Exception, e:
        return exit_with_general_critical(e)


def check_lock(con, warning, critical, perf_data):
    warning = warning or 10
    critical = critical or 30
    try:
        data = get_server_status(con)
        #
        # calculate percentage
        #
        lock_percentage = float(data['globalLock']['lockTime']) / float(data['globalLock']['totalTime']) * 100
        message = "Lock Percentage: %.2f%%" % lock_percentage
        message += performance_data(perf_data, [("%.2f" % lock_percentage, "lock_percentage", warning, critical)])
        return check_levels(lock_percentage, warning, critical, message)

    except Exception, e:
        return exit_with_general_critical(e)


def check_flushing(con, warning, critical, avg, perf_data):
    #
    # These thresholds mean it's taking 5 seconds to perform a background flush to issue a warning
    # and 10 seconds to issue a critical.
    #
    warning = warning or 5000
    critical = critical or 15000
    try:
        data = get_server_status(con)
        if avg:
            flush_time = float(data['backgroundFlushing']['average_ms'])
            stat_type = "Average"
        else:
            flush_time = float(data['backgroundFlushing']['last_ms'])
            stat_type = "Last"

        message = "%s Flush Time: %.2fms" % (stat_type, flush_time)
        message += performance_data(perf_data, [("%.2fms" % flush_time, "%s_flush_time" % stat_type.lower(), warning, critical)])

        return check_levels(flush_time, warning, critical, message)

    except Exception, e:
        return exit_with_general_critical(e)


def index_miss_ratio(con, warning, critical, perf_data):
    warning = warning or 10
    critical = critical or 30
    try:
        data = get_server_status(con)

        try:
            serverVersion = tuple(con.server_info()['version'].split('.'))
            if serverVersion >= tuple("2.4.0".split(".")):
                miss_ratio = float(data['indexCounters']['missRatio'])
            else:
                miss_ratio = float(data['indexCounters']['btree']['missRatio'])
        except KeyError:
            not_supported_msg = "not supported on this platform"
            if data['indexCounters'].has_key('note'):
                print "OK - MongoDB says: " + not_supported_msg
                return 0
            else:
                print "WARNING - Can't get counter from MongoDB"
                return 1

        message = "Miss Ratio: %.2f" % miss_ratio
        message += performance_data(perf_data, [("%.2f" % miss_ratio, "index_miss_ratio", warning, critical)])

        return check_levels(miss_ratio, warning, critical, message)

    except Exception, e:
        return exit_with_general_critical(e)

def check_replset_quorum(con, perf_data):
    db = con['admin']
    warning = 1
    critical = 2
    primary = 0

    try:
        rs_members = db.command("replSetGetStatus")['members']

        for member in rs_members:
            if member['state'] == 1:
                primary += 1

        if primary == 1:
            state = 0
            message = "Cluster is quorate"
        else:
            state = 2
            message = "Cluster is not quorate and cannot operate"

        return check_levels(state, warning, critical, message)
    except Exception, e:
        return exit_with_general_critical(e)



def check_replset_state(con, perf_data, warning="", critical=""):
    try:
        warning = [int(x) for x in warning.split(",")]
    except:
        warning = [0, 3, 5]
    try:
        critical = [int(x) for x in critical.split(",")]
    except:
        critical = [8, 4, -1]

    ok = range(-1, 8)  # should include the range of all posiible values
    try:
        try:
            try:
                set_read_preference(con.admin)
                data = con.admin.command(pymongo.son_manipulator.SON([('replSetGetStatus', 1)]))
            except:
                data = con.admin.command(son.SON([('replSetGetStatus', 1)]))
            state = int(data['myState'])
        except pymongo.errors.OperationFailure, e:
            if e.code == None and str(e).find('failed: not running with --replSet"'):
                state = -1

        if state == 8:
            message = "State: %i (Down)" % state
        elif state == 4:
            message = "State: %i (Fatal error)" % state
        elif state == 0:
            message = "State: %i (Starting up, phase1)" % state
        elif state == 3:
            message = "State: %i (Recovering)" % state
        elif state == 5:
            message = "State: %i (Starting up, phase2)" % state
        elif state == 1:
            message = "State: %i (Primary)" % state
        elif state == 2:
            message = "State: %i (Secondary)" % state
        elif state == 7:
            message = "State: %i (Arbiter)" % state
        elif state == -1:
            message = "Not running with replSet"
        else:
            message = "State: %i (Unknown state)" % state
        message += performance_data(perf_data, [(state, "state")])
        return check_levels(state, warning, critical, message, ok)
    except Exception, e:
        return exit_with_general_critical(e)


def check_databases(con, warning, critical, perf_data=None):
    try:
        try:
            set_read_preference(con.admin)
            data = con.admin.command(pymongo.son_manipulator.SON([('listDatabases', 1)]))
        except:
            data = con.admin.command(son.SON([('listDatabases', 1)]))

        count = len(data['databases'])
        message = "Number of DBs: %.0f" % count
        message += performance_data(perf_data, [(count, "databases", warning, critical, message)])
        return check_levels(count, warning, critical, message)
    except Exception, e:
        return exit_with_general_critical(e)


def check_collections(con, warning, critical, perf_data=None):
    try:
        try:
            set_read_preference(con.admin)
            data = con.admin.command(pymongo.son_manipulator.SON([('listDatabases', 1)]))
        except:
            data = con.admin.command(son.SON([('listDatabases', 1)]))

        count = 0
        for db in data['databases']:
            dbase = con[db['name']]
            set_read_preference(dbase)
            count += len(dbase.collection_names())

        message = "Number of collections: %.0f" % count
        message += performance_data(perf_data, [(count, "collections", warning, critical, message)])
        return check_levels(count, warning, critical, message)

    except Exception, e:
        return exit_with_general_critical(e)


def check_all_databases_size(con, warning, critical, perf_data):
    warning = warning or 100
    critical = critical or 1000
    try:
        set_read_preference(con.admin)
        all_dbs_data = con.admin.command(pymongo.son_manipulator.SON([('listDatabases', 1)]))
    except:
        all_dbs_data = con.admin.command(son.SON([('listDatabases', 1)]))

    total_storage_size = 0
    message = ""
    perf_data_param = [()]
    for db in all_dbs_data['databases']:
        database = db['name']
        data = con[database].command('dbstats')
        storage_size = round(data['storageSize'] / 1024 / 1024, 1)
        message += "; Database %s size: %.0f MB" % (database, storage_size)
        perf_data_param.append((storage_size, database + "_database_size"))
        total_storage_size += storage_size

    perf_data_param[0] = (total_storage_size, "total_size", warning, critical)
    message += performance_data(perf_data, perf_data_param)
    message = "Total size: %.0f MB" % total_storage_size + message
    return check_levels(total_storage_size, warning, critical, message)


def check_database_size(con, database, warning, critical, perf_data):
    warning = warning or 100
    critical = critical or 1000
    perfdata = ""
    try:
        set_read_preference(con.admin)
        data = con[database].command('dbstats')
        storage_size = data['storageSize'] / 1024 / 1024
        if perf_data:
            perfdata += " | database_size=%i;%i;%i" % (storage_size, warning, critical)
            #perfdata += " database=%s" %(database)

        if storage_size >= critical:
            print "CRITICAL - Database size: %.0f MB, Database: %s%s" % (storage_size, database, perfdata)
            return 2
        elif storage_size >= warning:
            print "WARNING - Database size: %.0f MB, Database: %s%s" % (storage_size, database, perfdata)
            return 1
        else:
            print "OK - Database size: %.0f MB, Database: %s%s" % (storage_size, database, perfdata)
            return 0
    except Exception, e:
        return exit_with_general_critical(e)


def check_database_indexes(con, database, warning, critical, perf_data):
    #
    # These thresholds are basically meaningless, and must be customized to your application
    #
    warning = warning or 100
    critical = critical or 1000
    perfdata = ""
    try:
        set_read_preference(con.admin)
        data = con[database].command('dbstats')
        index_size = data['indexSize'] / 1024 / 1024
        if perf_data:
            perfdata += " | database_indexes=%i;%i;%i" % (index_size, warning, critical)

        if index_size >= critical:
            print "CRITICAL - %s indexSize: %.0f MB %s" % (database, index_size, perfdata)
            return 2
        elif index_size >= warning:
            print "WARNING - %s indexSize: %.0f MB %s" % (database, index_size, perfdata)
            return 1
        else:
            print "OK - %s indexSize: %.0f MB %s" % (database, index_size, perfdata)
            return 0
    except Exception, e:
        return exit_with_general_critical(e)


def check_collection_indexes(con, database, collection, warning, critical, perf_data):
    #
    # These thresholds are basically meaningless, and must be customized to your application
    #
    warning = warning or 100
    critical = critical or 1000
    perfdata = ""
    try:
        set_read_preference(con.admin)
        data = con[database].command('collstats', collection)
        total_index_size = data['totalIndexSize'] / 1024 / 1024
        if perf_data:
            perfdata += " | collection_indexes=%i;%i;%i" % (total_index_size, warning, critical)

        if total_index_size >= critical:
            print "CRITICAL - %s.%s totalIndexSize: %.0f MB %s" % (database, collection, total_index_size, perfdata)
            return 2
        elif total_index_size >= warning:
            print "WARNING - %s.%s totalIndexSize: %.0f MB %s" % (database, collection, total_index_size, perfdata)
            return 1
        else:
            print "OK - %s.%s totalIndexSize: %.0f MB %s" % (database, collection, total_index_size, perfdata)
            return 0
    except Exception, e:
        return exit_with_general_critical(e)


def check_queues(con, warning, critical, perf_data):
    warning = warning or 10
    critical = critical or 30
    try:
        data = get_server_status(con)

        total_queues = float(data['globalLock']['currentQueue']['total'])
        readers_queues = float(data['globalLock']['currentQueue']['readers'])
        writers_queues = float(data['globalLock']['currentQueue']['writers'])
        message = "Current queue is : total = %d, readers = %d, writers = %d" % (total_queues, readers_queues, writers_queues)
        message += performance_data(perf_data, [(total_queues, "total_queues", warning, critical), (readers_queues, "readers_queues"), (writers_queues, "writers_queues")])
        return check_levels(total_queues, warning, critical, message)

    except Exception, e:
        return exit_with_general_critical(e)

def check_collection_size(con, database, collection, warning, critical, perf_data):
    warning = warning or 100
    critical = critical or 1000
    perfdata = ""
    try:
        set_read_preference(con.admin)
        data = con[database].command('collstats', collection)
        size = data['size'] / 1024 / 1024
        if perf_data:
            perfdata += " | collection_size=%i;%i;%i" % (size, warning, critical)

        if size >= critical:
            print "CRITICAL - %s.%s size: %.0f MB %s" % (database, collection, size, perfdata)
            return 2
        elif size >= warning:
            print "WARNING - %s.%s size: %.0f MB %s" % (database, collection, size, perfdata)
            return 1
        else:
            print "OK - %s.%s size: %.0f MB %s" % (database, collection, size, perfdata)
            return 0
    except Exception, e:
        return exit_with_general_critical(e)

def check_queries_per_second(con, query_type, warning, critical, perf_data):
    warning = warning or 250
    critical = critical or 500

    if query_type not in ['insert', 'query', 'update', 'delete', 'getmore', 'command']:
        return exit_with_general_critical("The query type of '%s' is not valid" % query_type)

    try:
        db = con.local
        data = get_server_status(con)

        # grab the count
        num = int(data['opcounters'][query_type])

        # do the math
        last_count = db.nagios_check.find_one({'check': 'query_counts'})
        try:
            ts = int(time.time())
            diff_query = num - last_count['data'][query_type]['count']
            diff_ts = ts - last_count['data'][query_type]['ts']

            query_per_sec = float(diff_query) / float(diff_ts)

            # update the count now
            db.nagios_check.update({u'_id': last_count['_id']}, {'$set': {"data.%s" % query_type: {'count': num, 'ts': int(time.time())}}})

            message = "Queries / Sec: %f" % query_per_sec
            message += performance_data(perf_data, [(query_per_sec, "%s_per_sec" % query_type, warning, critical, message)])
        except KeyError:
            #
            # since it is the first run insert it
            query_per_sec = 0
            message = "First run of check.. no data"
            db.nagios_check.update({u'_id': last_count['_id']}, {'$set': {"data.%s" % query_type: {'count': num, 'ts': int(time.time())}}})
        except TypeError:
            #
            # since it is the first run insert it
            query_per_sec = 0
            message = "First run of check.. no data"
            db.nagios_check.insert({'check': 'query_counts', 'data': {query_type: {'count': num, 'ts': int(time.time())}}})

        return check_levels(query_per_sec, warning, critical, message)

    except Exception, e:
        return exit_with_general_critical(e)


def check_oplog(con, warning, critical, perf_data):
    """ Checking the oplog time - the time of the log currntly saved in the oplog collection
    defaults:
        critical 4 hours
        warning 24 hours
    those can be changed as usual with -C and -W parameters"""
    warning = warning or 24
    critical = critical or 4
    try:
        db = con.local
        ol = db.system.namespaces.find_one({"name": "local.oplog.rs"})
        if (db.system.namespaces.find_one({"name": "local.oplog.rs"}) != None):
            oplog = "oplog.rs"
        else:
            ol = db.system.namespaces.find_one({"name": "local.oplog.$main"})
            if (db.system.namespaces.find_one({"name": "local.oplog.$main"}) != None):
                oplog = "oplog.$main"
            else:
                message = "neither master/slave nor replica set replication detected"
                return check_levels(None, warning, critical, message)

        try:
                set_read_preference(con.admin)
                data = con.local.command(pymongo.son_manipulator.SON([('collstats', oplog)]))
        except:
                data = con.admin.command(son.SON([('collstats', oplog)]))

        ol_size = data['size']
        ol_storage_size = data['storageSize']
        ol_used_storage = int(float(ol_size) / ol_storage_size * 100 + 1)
        ol = con.local[oplog]
        firstc = ol.find().sort("$natural", pymongo.ASCENDING).limit(1)[0]['ts']
        lastc = ol.find().sort("$natural", pymongo.DESCENDING).limit(1)[0]['ts']
        time_in_oplog = (lastc.as_datetime() - firstc.as_datetime())
        message = "Oplog saves " + str(time_in_oplog) + " %d%% used" % ol_used_storage
        try:  # work starting from python2.7
            hours_in_oplog = time_in_oplog.total_seconds() / 60 / 60
        except:
            hours_in_oplog = float(time_in_oplog.seconds + time_in_oplog.days * 24 * 3600) / 60 / 60
        approx_level = hours_in_oplog * 100 / ol_used_storage
        message += performance_data(perf_data, [("%.2f" % hours_in_oplog, 'oplog_time', warning, critical), ("%.2f " % approx_level, 'oplog_time_100_percent_used')])
        return check_levels(-approx_level, -warning, -critical, message)

    except Exception, e:
        return exit_with_general_critical(e)


def check_journal_commits_in_wl(con, warning, critical, perf_data):
    """  Checking the number of commits which occurred in the db's write lock.
Most commits are performed outside of this lock; committed while in the write lock is undesirable.
Under very high write situations it is normal for this value to be nonzero.  """

    warning = warning or 10
    critical = critical or 40
    try:
        data = get_server_status(con)
        j_commits_in_wl = data['dur']['commitsInWriteLock']
        message = "Journal commits in DB write lock : %d" % j_commits_in_wl
        message += performance_data(perf_data, [(j_commits_in_wl, "j_commits_in_wl", warning, critical)])
        return check_levels(j_commits_in_wl, warning, critical, message)

    except Exception, e:
        return exit_with_general_critical(e)


def check_journaled(con, warning, critical, perf_data):
    """ Checking the average amount of data in megabytes written to the recovery log in the last four seconds"""

    warning = warning or 20
    critical = critical or 40
    try:
        data = get_server_status(con)
        journaled = data['dur']['journaledMB']
        message = "Journaled : %.2f MB" % journaled
        message += performance_data(perf_data, [("%.2f" % journaled, "journaled", warning, critical)])
        return check_levels(journaled, warning, critical, message)

    except Exception, e:
        return exit_with_general_critical(e)


def check_write_to_datafiles(con, warning, critical, perf_data):
    """    Checking the average amount of data in megabytes written to the databases datafiles in the last four seconds.
As these writes are already journaled, they can occur lazily, and thus the number indicated here may be lower
than the amount physically written to disk."""
    warning = warning or 20
    critical = critical or 40
    try:
        data = get_server_status(con)
        writes = data['dur']['writeToDataFilesMB']
        message = "Write to data files : %.2f MB" % writes
        message += performance_data(perf_data, [("%.2f" % writes, "write_to_data_files", warning, critical)])
        return check_levels(writes, warning, critical, message)

    except Exception, e:
        return exit_with_general_critical(e)


def get_opcounters(data, opcounters_name, host):
    try:
        insert = data[opcounters_name]['insert']
        query = data[opcounters_name]['query']
        update = data[opcounters_name]['update']
        delete = data[opcounters_name]['delete']
        getmore = data[opcounters_name]['getmore']
        command = data[opcounters_name]['command']
    except KeyError, e:
        return 0, [0] * 100
    total_commands = insert + query + update + delete + getmore + command
    new_vals = [total_commands, insert, query, update, delete, getmore, command]
    return  maintain_delta(new_vals, host, opcounters_name)


def check_opcounters(con, host, warning, critical, perf_data):
    """ A function to get all opcounters delta per minute. In case of a replication - gets the opcounters+opcountersRepl"""
    warning = warning or 10000
    critical = critical or 15000

    data = get_server_status(con)
    err1, delta_opcounters = get_opcounters(data, 'opcounters', host)
    err2, delta_opcounters_repl = get_opcounters(data, 'opcountersRepl', host)
    if err1 == 0 and err2 == 0:
        delta = [(x + y) for x, y in zip(delta_opcounters, delta_opcounters_repl)]
        delta[0] = delta_opcounters[0]  # only the time delta shouldn't be summarized
        per_minute_delta = [int(x / delta[0] * 60) for x in delta[1:]]
        message = "Test succeeded , old values missing"
        message = "Opcounters: total=%d,insert=%d,query=%d,update=%d,delete=%d,getmore=%d,command=%d" % tuple(per_minute_delta)
        message += performance_data(perf_data, ([(per_minute_delta[0], "total", warning, critical), (per_minute_delta[1], "insert"),
                    (per_minute_delta[2], "query"), (per_minute_delta[3], "update"), (per_minute_delta[5], "delete"),
                    (per_minute_delta[5], "getmore"), (per_minute_delta[6], "command")]))
        return check_levels(per_minute_delta[0], warning, critical, message)
    else:
        return exit_with_general_critical("problem reading data from temp file")


def check_current_lock(con, host, warning, critical, perf_data):
    """ A function to get current lock percentage and not a global one, as check_lock function does"""
    warning = warning or 10
    critical = critical or 30
    data = get_server_status(con)

    lockTime = float(data['globalLock']['lockTime'])
    totalTime = float(data['globalLock']['totalTime'])

    err, delta = maintain_delta([totalTime, lockTime], host, "locktime")
    if err == 0:
        lock_percentage = delta[2] / delta[1] * 100     # lockTime/totalTime*100
        message = "Current Lock Percentage: %.2f%%" % lock_percentage
        message += performance_data(perf_data, [("%.2f" % lock_percentage, "current_lock_percentage", warning, critical)])
        return check_levels(lock_percentage, warning, critical, message)
    else:
        return exit_with_general_warning("problem reading data from temp file")


def check_page_faults(con, host, warning, critical, perf_data):
    """ A function to get page_faults per second from the system"""
    warning = warning or 10
    critical = critical or 30
    data = get_server_status(con)

    try:
        page_faults = float(data['extra_info']['page_faults'])
    except:
        # page_faults unsupported on the underlaying system
        return exit_with_general_critical("page_faults unsupported on the underlaying system")

    err, delta = maintain_delta([page_faults], host, "page_faults")
    if err == 0:
        page_faults_ps = delta[1] / delta[0]
        message = "Page faults : %.2f ps" % page_faults_ps
        message += performance_data(perf_data, [("%.2f" % page_faults_ps, "page_faults_ps", warning, critical)])
        return check_levels(page_faults_ps, warning, critical, message)
    else:
        return exit_with_general_warning("problem reading data from temp file")


def check_asserts(con, host, warning, critical, perf_data):
    """ A function to get asserts from the system"""
    warning = warning or 1
    critical = critical or 10
    data = get_server_status(con)

    asserts = data['asserts']

    #{ "regular" : 0, "warning" : 6, "msg" : 0, "user" : 12, "rollovers" : 0 }
    regular = asserts['regular']
    warning_asserts = asserts['warning']
    msg = asserts['msg']
    user = asserts['user']
    rollovers = asserts['rollovers']

    err, delta = maintain_delta([regular, warning_asserts, msg, user, rollovers], host, "asserts")

    if err == 0:
        if delta[5] != 0:
            #the number of rollovers were increased
            warning = -1  # no matter the metrics this situation should raise a warning
            # if this is normal rollover - the warning will not appear again, but if there will be a lot of asserts
            # the warning will stay for a long period of time
            # although this is not a usual situation

        regular_ps = delta[1] / delta[0]
        warning_ps = delta[2] / delta[0]
        msg_ps = delta[3] / delta[0]
        user_ps = delta[4] / delta[0]
        rollovers_ps = delta[5] / delta[0]
        total_ps = regular_ps + warning_ps + msg_ps + user_ps
        message = "Total asserts : %.2f ps" % total_ps
        message += performance_data(perf_data, [(total_ps, "asserts_ps", warning, critical), (regular_ps, "regular"),
                    (warning_ps, "warning"), (msg_ps, "msg"), (user_ps, "user")])
        return check_levels(total_ps, warning, critical, message)
    else:
        return exit_with_general_warning("problem reading data from temp file")


def get_stored_primary_server_name(db):
    """ get the stored primary server name from db. """
    if "last_primary_server" in db.collection_names():
        stored_primary_server = db.last_primary_server.find_one()["server"]
    else:
        stored_primary_server = None

    return stored_primary_server


def check_replica_primary(con, host, warning, critical, perf_data, replicaset):
    """ A function to check if the primary server of a replica set has changed """
    if warning is None and critical is None:
        warning = 1
    warning = warning or 2
    critical = critical or 2

    primary_status = 0
    message = "Primary server has not changed"
    db = con["nagios"]
    data = get_server_status(con)
    if replicaset != data['repl'].get('setName'):
        message = "Replica set requested: %s differs from the one found: %s" % (replicaset, data['repl'].get('setName'))
        primary_status = 2
        return check_levels(primary_status, warning, critical, message)
    current_primary = data['repl'].get('primary')
    saved_primary = get_stored_primary_server_name(db)
    if current_primary is None:
        current_primary = "None"
    if saved_primary is None:
        saved_primary = "None"
    if current_primary != saved_primary:
        last_primary_server_record = {"server": current_primary}
        db.last_primary_server.update({"_id": "last_primary"}, {"$set": last_primary_server_record}, upsert=True, safe=True)
        message = "Primary server has changed from %s to %s" % (saved_primary, current_primary)
        primary_status = 1
    return check_levels(primary_status, warning, critical, message)


def check_page_faults(con, sample_time, warning, critical, perf_data):
    warning = warning or 10
    critical = critical or 20
    try:
        try:
            set_read_preference(con.admin)
            data1 = con.admin.command(pymongo.son_manipulator.SON([('serverStatus', 1)]))
            time.sleep(sample_time)
            data2 = con.admin.command(pymongo.son_manipulator.SON([('serverStatus', 1)]))
        except:
            data1 = con.admin.command(son.SON([('serverStatus', 1)]))
            time.sleep(sample_time)
            data2 = con.admin.command(son.SON([('serverStatus', 1)]))

        try:
            #on linux servers only
            page_faults = (int(data2['extra_info']['page_faults']) - int(data1['extra_info']['page_faults'])) / sample_time
        except KeyError:
            print "WARNING - Can't get extra_info.page_faults counter from MongoDB"
            sys.exit(1)

        message = "Page Faults: %i" % (page_faults)

        message += performance_data(perf_data, [(page_faults, "page_faults", warning, critical)])
        check_levels(page_faults, warning, critical, message)

    except Exception, e:
        exit_with_general_critical(e)


def chunks_balance(con, database, collection, warning, critical):
    warning = warning or 10
    critical = critical or 20
    nsfilter = database + "." + collection
    try:
        try:
            set_read_preference(con.admin)
            col = con.config.chunks
            nscount = col.find({"ns": nsfilter}).count()
            shards = col.distinct("shard")

        except:
            print "WARNING - Can't get chunks infos from MongoDB"
            sys.exit(1)

        if nscount == 0:
            print "WARNING - Namespace %s is not sharded" % (nsfilter)
            sys.exit(1)

        avgchunksnb = nscount / len(shards)
        warningnb = avgchunksnb * warning / 100
        criticalnb = avgchunksnb * critical / 100

        for shard in shards:
            delta = abs(avgchunksnb - col.find({"ns": nsfilter, "shard": shard}).count())
            message = "Namespace: %s, Shard name: %s, Chunk delta: %i" % (nsfilter, shard, delta)

            if delta >= criticalnb and delta > 0:
                print "CRITICAL - Chunks not well balanced " + message
                sys.exit(2)
            elif delta >= warningnb  and delta > 0:
                print "WARNING - Chunks not well balanced  " + message
                sys.exit(1)

        print "OK - Chunks well balanced across shards"
        sys.exit(0)

    except Exception, e:
        exit_with_general_critical(e)

    print "OK - Chunks well balanced across shards"
    sys.exit(0)


def check_connect_primary(con, warning, critical, perf_data):
    warning = warning or 3
    critical = critical or 6

    try:
        try:
            set_read_preference(con.admin)
            data = con.admin.command(pymongo.son_manipulator.SON([('isMaster', 1)]))
        except:
            data = con.admin.command(son.SON([('isMaster', 1)]))

        if data['ismaster'] == True:
            print "OK - This server is primary"
            return 0

        phost = data['primary'].split(':')[0]
        pport = int(data['primary'].split(':')[1])
        start = time.time()

        err, con = mongo_connect(phost, pport)
        if err != 0:
            return err

        pconn_time = time.time() - start
        pconn_time = round(pconn_time, 0)
        message = "Connection to primary server " + data['primary'] + " took %i seconds" % pconn_time
        message += performance_data(perf_data, [(pconn_time, "connection_time", warning, critical)])

        return check_levels(pconn_time, warning, critical, message)

    except Exception, e:
        return exit_with_general_critical(e)


def check_collection_state(con, database, collection):
    try:
        con[database][collection].find_one()
        print "OK - Collection %s.%s is reachable " % (database, collection)
        return 0

    except Exception, e:
        return exit_with_general_critical(e)


def check_row_count(con, database, collection, warning, critical, perf_data):
    try:
        count = con[database][collection].count()
        message = "Row count: %i" % (count)
        message += performance_data(perf_data, [(count, "row_count", warning, critical)])

        return check_levels(count, warning, critical, message)

    except Exception, e:
        return exit_with_general_critical(e)


def build_file_name(host, action):
    #done this way so it will work when run independently and from shell
    module_name = re.match('(.*//*)*(.*)\..*', __file__).group(2)
    return "/tmp/" + module_name + "_data/" + host + "-" + action + ".data"


def ensure_dir(f):
    d = os.path.dirname(f)
    if not os.path.exists(d):
        os.makedirs(d)


def write_values(file_name, string):
    f = None
    try:
        f = open(file_name, 'w')
    except IOError, e:
        #try creating
        if (e.errno == 2):
            ensure_dir(file_name)
            f = open(file_name, 'w')
        else:
            raise IOError(e)
    f.write(string)
    f.close()
    return 0


def read_values(file_name):
    data = None
    try:
        f = open(file_name, 'r')
        data = f.read()
        f.close()
        return 0, data
    except IOError, e:
        if (e.errno == 2):
            #no previous data
            return 1, ''
    except Exception, e:
        return 2, None


def calc_delta(old, new):
    delta = []
    if (len(old) != len(new)):
        raise Exception("unequal number of parameters")
    for i in range(0, len(old)):
        val = float(new[i]) - float(old[i])
        if val < 0:
            val = new[i]
        delta.append(val)
    return 0, delta


def maintain_delta(new_vals, host, action):
    file_name = build_file_name(host, action)
    err, data = read_values(file_name)
    old_vals = data.split(';')
    new_vals = [str(int(time.time()))] + new_vals
    delta = None
    try:
        err, delta = calc_delta(old_vals, new_vals)
    except:
        err = 2
    write_res = write_values(file_name, ";" . join(str(x) for x in new_vals))
    return err + write_res, delta


def replication_get_time_diff(con):
    col = 'oplog.rs'
    local = con.local
    ol = local.system.namespaces.find_one({"name": "local.oplog.$main"})
    if ol:
        col = 'oplog.$main'
    firstc = local[col].find().sort("$natural", 1).limit(1)
    lastc = local[col].find().sort("$natural", -1).limit(1)
    first = firstc.next()
    last = lastc.next()
    tfirst = first["ts"]
    tlast = last["ts"]
    delta = tlast.time - tfirst.time
    return delta

#
# main app
#
if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
