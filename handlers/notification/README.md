# Notification handlers

## mailer

The following three configuration variables must be set if you want mailer to use remote SMTP settings:

    smtp_address - defaults to "localhost"
    smtp_port - defaults to "25"
    smtp_domain - defaults to "localhost.localdomain"

There is an optional subscriptions hash which can be added to your mailer.json file.  This subscriptions hash allows you to define individual mail_to addresses for a given subscription.  When the mailer handler runs it will check the clients subscriptions and build a mail_to string with the default mailer.mail_to address as well as any subscriptions the client subscribes to where a mail_to address is found.  There can be N number of hashes inside of subscriptions but the key for a given hash inside of subscriptions must match a subscription name. 

{
  "mailer": {
    "mail_from": "sensu@example.com",
    "mail_to": "monitor@example.com",
    "smtp_address": "smtp.example.org",
    "smtp_port": "25",
    "smtp_domain": "example.org",
    "subsciptions": {
        "subscription_name": {
            "mail_to": "teamemail@example.com"
    }
  }
}


