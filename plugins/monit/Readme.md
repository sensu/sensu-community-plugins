Monit plugin for sensu
======================

Do you already have Monit running for your process monitoring and restarting but want to add sensu to your monitoring tool belt?  Now you can have the best of both worlds and pipe in your Monit notifications in to sensu.

Notes
-----

I currently use an array of "Events" that monit produce to figure out if the alert should be critical or resolved.  Also monit does not seem to have a warning level so I leave that out.  And as with all open source projects this should be treated as alpha code and needs more TLC.

Requirements
-------------
You will need the mail gem to parse the monit email.  We dont send any email but do receive it.

  $ (sudo) gem install mail

Configuration
-------------

The setup is very different from other sensu plugins so RTFM.

* Place monit-email.rb in a location that postfix can access it and execute it.  Recommended location is <sensu instal director>/plugins/
* Configure postfix to pipe messages from monit email address to monit-email.rb plugin
  * Create/Modify postfix transport at /etc/postfix/transport
    ```
    monit@hipchat.com       monit:
    ```
  * Create transport map db
    $ postmap /etc/postfix/transport
  * Add transport_map to main.cf
    ```
    transport_maps = hash:/etc/postfix/transport
    ```
  * Add the following to your master.cf
    ```
    #==========================================================================
    # service type  private unpriv  chroot  wakeup  maxproc command + args
    #               (yes)   (yes)   (yes)   (never) (100)
    #==========================================================================

    monit   unix    -       n       n       -       -       pipe
    user=sensu argv=/etc/sensu/plugins/monit-email.rb
    ```
  * Reload postifx
    $ sudo service postfix reload

License
_______
Copyright (c) Atlassian, Inc.

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.