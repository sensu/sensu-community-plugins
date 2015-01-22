#!/bin/bash
#
# Ceilometer Compute Agent monitoring script for Sensu
#
# Copyright © 2013 eNovance <licensing@enovance.com>
#
# Author: Emilien Macchi <emilien.macchi@enovance.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
# If not running as root, requires this line in /etc/sudoers:
# sensu  ALL=(ALL) NOPASSWD: /bin/netstat -epta
#

# #RED
set -e

STATE_OK=0
STATE_WARNING=1
STATE_CRITICAL=2
STATE_UNKNOWN=3
STATE_DEPENDENT=4


PID=$(pidof -x ceilometer-agent-compute)

if ! KEY=$(sudo /bin/netstat -epta 2>/dev/null | grep $PID | grep amqp)
then
    echo "Ceilometer Compute Agent is not connected to AMQP."
    exit $STATE_CRITICAL
fi

echo "Ceilometer Compute Agent is working."
