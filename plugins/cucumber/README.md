# check-cucumber

Sensu check that executes Cucumber tests

The check supports:
* cucumber-js
* cucumber-jvm
* Ruby Cucumber
* parallel-cucumber-js

## Example Sensu config

Example check_cucumber.json:

``` json
{
  "checks": {
    "check_cucumber_example": {
      "handlers": ["default"],
      "command": "check-cucumber.rb --name cucumber-example --handler cucumber --metric-handler metrics --metric-prefix example-metrics-prefix --command \"cucumber-js -f json features/\" --working-dir cucumber-example/",
      "interval": 60,
      "subscribers": [ "cucumber" ]
    }
  }
}
```
