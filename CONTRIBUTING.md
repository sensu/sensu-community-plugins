# Developer Guidelines

If you have a new plugin or handler, send a pull request! Don't be afraid on pushing your PR with non-ruby code. Just let someone from [team](https://github.com/sensu?tab=members) know. Maybe we can help you to rewrite your check to Ruby or even invent something completely new to test your work. Just don't hesitate to contact us.
 
## Naming Conventions

Please format the names of scripts using dashes to separate words and with an
extension (`.rb`, `.sh`, etc), and make sure they are `chmod +x`'d.
Extensions are unfortunately necessary for Sensu to be able to directly
exec plugins and handlers on Windows.

## Coding Style

When developing your plugins please use the [sensu plugin class](https://github.com/sensu/sensu-plugin).  This will ensure that all plugins have an identical run structure.

When using options please try and follow the following structure.  At the very least your option needs to include a description to assist the user with configration and deployment
```ruby
option :port,
       short: '-p PORT',
       long: '--port PORT',
       description: 'Port',
       default: '1234'
```

Each plugin, handler, mutator, extension should use the following standard header

````
#! /usr/bin/env ruby
#  encoding: UTF-8
#   <script name>
#
# DESCRIPTION:
#
# OUTPUT:
#   plain text, metric data, etc
#
# PLATFORMS:
#   Linux, Windows, BSD, Solaris, etc
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: <?>
#
# USAGE:
#
# NOTES:
#
# LICENSE:
#   <your name>  <your email>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#
````

## Documentation

All documentation will be handled by [RDoc](https://github.com/rdoc/rdoc) and we are using the default rdoc markup at this time. A brief introduction RDoc markup can be found [here](http://docs.seattlerb.org/rdoc/RDoc/Markup.html). All scripts should have as much documentation coverage as possible, ideally 100%.  You can test your coverage by installing RDoc locally and running

```shell
rdoc -C <filename>
```

The output will tell you how much coverage you have without spending the time building the docs.  

Documentation can always be made better, if you would like to contribute to it, have at it and submit a PR.

## Dependency Managment

Dependencies (ruby gems, packages, etc) and other requirements should
be declared in the header of the plugin/handler file.  Try to use the standard library or the same dependencies as other plugins to keep the stack as small as possible.  If you have questions about using a specific gem feel free to ask.

All scripts should contain the following dependency to ensure full compatibility.


```ruby
require 'rubygems' if RUBY_VERSION < '1.9.0'
```

## Vagrant Box

There is a Vagrantfile with shell provisioning that will setup the major versions of Ruby and a sensu gemset for each if you wish to use it.  To get started install [Vagrant](https://www.vagrantup.com/) then type *vagrant up* in the root directory of the repo.  Once it is up type *vagrant ssh* to remote into the box and then *cd /vagrant && bundle install* to set all necessary dependencies.

The box currently defaults to Ruby 2.1.4 but has 1.9.2, 1.9.3 and 2.0.0 installed as well.  See the file comments for further details.

## Testing

### Linting
Only pull requests passing lint/tests will be merged.

Rubocop is used to lint the style of the ruby plugins. This is done
to standardize the style used within these plugins, and ensure high
quality code.  Most current rules are currently in effect.  No linting is done on Ruby code prior to version 1.9.3 as Rubocop requires 1.9.2 and linting for it is identical to 1.9.3.  See the [travis.yml](.travis.yml) and [Rakefile](Rakefile) for details on what tests and versions are currently supported.  There are currently no plans to support Ruby 1.8.x

You can test rubocop compliance for yourself by installing the gem and running <i>rubocop</i> from the command line.
Running <i>rubocop -a</i> will attempt to autocorrect any issues, saving yourself considerable time in large files.

If it truely makes sense for your code to violate a rule you can disable that rule with your code by either using

    # rubocop:disable <rule>, <rule>


at the end of the line in violation or

    rubocop:disable <rule>, <rule>
    <code block>
    rubocop:enable <rule>, <rule>

If you use either of these methods please mention in the PR as this should be kept to an absolute minimum at times, especially concerning method length and complexity, it makes sense to use on of the above methods.

### Rspec

Currently we have RSpec3 as a [test framework](https://github.com/sensu/sensu-plugin-spec). Please add coverage for your check.  Checks will not be considered production grade and stable until they have complete coverage.

You can use the included Vagrantfile for easy testing.  All necessary versions of Ruby can be installed with their own dedicated gem sets using RVM.  Just boot up the machine and drop into /vagrant and execute

    rake default
 
to run all specs and rubocop tests.  RSpec tests are currently run against 1.9.2, 1.9.3, 2.0, and 2.1.  There are currently no plans to support 1.8.x.
   
This is ~~little bit hard~~ almost impossible for non-ruby checks. Let someone from [team](https://github.com/sensu?tab=members) know and maybe can can help.

## Issue and Pull Request Submissions

If you see something wrong or come across a bug please open up an issue.  Try to include as much data in the issue as possible.  If you feel the issue is critical than tag a core  member and we will respond as soon as is feasible.

When submitting a pull request please follow the guidelines below for the quickest possible merge.  These not only make our lives eaiser, but also keep the repo and commit history as clean as possible.

* When at all possible do a  ```git pull --rebase``` both before you start working on the repo and then before you commit.  This will help ensure you have the most up to date codebase, Rubocop rules, and documentation.  It will also go along way towards cutting down or eliminating(hopefully) annoying merge commits.
* 

If you wish to track the status of your PR or issue, check out our [waffle.io](https://waffle.io/sensu/sensu-community-plugins).  This single location will allow contributers to stay on top of interwinding issues more effectively.

Please do not not abandon your pull request, only you can help us merge it. We will wait for feedback from you on your pull request for up to one month. A lack of feedback in one month may require you to re-open your pull request.  

## Technical Debt

For those who don't deal with or understand technical debt, it is debt incurred when designing or developing software.  All the #FIXME, #HACK, etc littered through a script add up over time, this is your technical debt.

### Technical Debt Levels

**YELLOW**

* simple issues that require basic Ruby and no more than 4 hours to fix

**ORANGE**

* these may require 4 - 8 hours but still only a basic or intermediate Ruby skillset

**RED**

* may require 8+ hours or some domain specific Ruby skills such as Amazon, or Elastic Search

In order to quantify it and see what we actually have there is a rake task *calculate_debt*.  In order to run it you will need an auth token and write access to the repo.

There are three locked issues on Github corresponding the to level of debt, if you want to help out just grab a file and tag it for fixing by either the original maintainer or another community member or fix it yourself if you can and submit a PR.
