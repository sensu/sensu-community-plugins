
# Sensu Pingdom Plugins

Sensu plugins that integrate with the [Pingdom
API](https://www.pingdom.com/services/api-documentation-rest/).

### Requirements

A valid Pingdom user and password, along with a registered API key.

### Common Flags

Every API call is sent over a secure HTTPS connection with basic
authentication and an API key embedded in every request.

* `-u, --user`: Pingdom user
* `-p, --password`: Pingdom password
* `-k, --pingdom-key`: Pingdom [API key](https://my.pingdom.com/account/appkeys)

### Aggregate Check

**check-pingdom-checks.rb** aggregates the number of checks that are
currently marked as 'down'.

Specific flags:

* `-w, --warning`: Warning threshold for DOWN checks
* `-c, --critical`: Critical threshold for DOWN checks
* `-v`: Verbose mode enables the listing of DOWN checks

### Available Credits Check

**check-pingdom-credits.rb** alerts if Pingdom credits fall below
specified thresholds.

Specific flags:

* `--warn-availablechecks`: Warning threshold for available checks
* `--crit-availablechecks`: Critical threshold for available checks
* `--warn-availablesms`: Warning threshold for available SMS alerts
* `--crit-availablesms`: Critical threshold for available SMS alerts

### References

* [https://www.pingdom.com/services/api-documentation-rest/](https://www.pingdom.com/services/api-documentation-rest/)
