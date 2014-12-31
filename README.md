# Sensu Community Plugins

[![Build Status](https://travis-ci.org/sensu/sensu-community-plugins.png?branch=master)](https://travis-ci.org/sensu/sensu-community-plugins)[![Code Climate](https://codeclimate.com/github/sensu/sensu-community-plugins/badges/gpa.svg)](https://codeclimate.com/github/sensu/sensu-community-plugins)[![Test Coverage](https://codeclimate.com/github/sensu/sensu-community-plugins/badges/coverage.svg)](https://codeclimate.com/github/sensu/sensu-community-plugins)

[![Backlog Issues](https://badge.waffle.io/sensu/sensu-community-plugins.svg?label=Backlog&title=Issue and Pull Request Backlog)](http://waffle.io/sensu/sensu-community-plugins)[![Issues In Progress](https://badge.waffle.io/sensu/sensu-community-plugins.svg?label=In%20Progress&title=In%20Progress)](http://waffle.io/sensu/sensu-community-plugins)

![sensu](https://raw.github.com/sensu/sensu/master/sensu-logo.png)

## Community plugins, extensions, and handlers

This gem contains some example plugins and handlers for Sensu. Most of
them are implemented in Ruby and use the `sensu-plugin` framework (a
small gem); some also depend on additional gems (e.g. `mysql`). Some
are shell scripts! All languages are welcome.

In the future, some sort of browsing/metadata/installation system may be
implemented. For now, just clone this repository, take a look around,
and copy the plugins you want to use.

## Production usage

Linters currently run against Ruby 1.9.3, 2.0 and 2.1 and RSpec3 tests are being written to support 1.9.2, 1.9.3, 2.0, and 2.1.  There are no plans to support prior versions of Ruby, if you have no access to these versions please use the embedded Ruby that is installed with Sensu.

Because of the nature of this repository:

* little test coverage
* specific and exotic software being checked
* no versioning system for plugins

this is not recommended that you use master for your production instances.
Better pick something which works for you and lock it via `:ref` in your
`chef || puppet || ansible || bash script` you name it.

If you have installed Sensu using the omnibus package it will use an embedded
version of ruby, but the ruby plugins here will use the system one. If you want
to use the embedded ruby, which has the `sensu-plugin` gem installed as well,
you can set `EMBEDDED_RUBY=true` in `/etc/default/sensu` and restart the Sensu
services. This will put the embedded ruby first in the $PATH for commands run
by the Sensu services.

## License

Copyright 2011 Sonian, Inc. and contributors.

Released under the same terms as Sensu (the MIT license); see LICENSE
for details.

NOTE: When adding a plugin, copy the preceding two paragraphs to a
comment in each source file, changing the copyright holder to your own
name or organization. If you wish to use a different open source
license, please submit a pull request adding that license to the repo
and use that license's boilerplate instead.
