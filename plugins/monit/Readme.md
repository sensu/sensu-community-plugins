Monit plugin for sensu
======================

Do you already have Monit running for your process monitoring and restarting but want to add sensu to your monitoring tool belt?  Now you can have the best of both worlds and pipe in your Monit notifications in to sensu.

Notes
-----

I currently use an array of "Events" that monit produce to figure out if the alert should be critical or resolved.  Also monit does not seem to have a warning level so I left that out.  You can learn more about monit events [here](http://mmonit.com/monit/documentation/monit.html#alert_messages)

As with all open source projects this should be treated as alpha code and needs more TLC.

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
    monit@domain.com       monit:
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
-----------
Copyright 2012 Atlassian, Inc. and contributors.

Released under the same terms as Sensu (the MIT license); see LICENSE for details.