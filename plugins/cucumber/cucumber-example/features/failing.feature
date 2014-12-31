Feature: Failing

  Scenario: Failing
    Given a passing pre-condition
    When a failing action is executed
    Then a post-condition passes
