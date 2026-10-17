# The Feature line is the report row: one short sentence, 70 characters at most,
# saying what this file tests. It is the group name in every surface CI renders.
Feature: Leaving and reopening the window without losing where you were

  Background:
    Given a backend with work on it
    And the app is running
    And I go to the work

  Scenario: leaving says what carries on without the window
    When I select the project {'checkout'}
    And I ask to close it
    Then it says {'porelo-checkout-shell'} keeps running

  Scenario: a decision that nothing will be listening for is said before leaving
    When work is blocked reaching {'api.example.test:443'}
    And I ask to close it
    Then it says {'Nothing will be listening for them once this closes'}

  Scenario: staying changes nothing
    When I ask to close it
    And I stay
    Then the app is still open

  Scenario: reopening comes back to the same selection
    When I select the project {'checkout'}
    And I select the work {'porelo-checkout-shell'}
    And the app is restarted
    And I go to the work
    Then the project {'checkout'} is selected
    And the work {'porelo-checkout-shell'} is still selected

  Scenario: reopening opens on the work, whichever section was left
    When I show what this session has run
    And the app is restarted
    Then the section shown is {'Work'}

  Scenario: a newer build installed underneath says so, and changes nothing on its own
    When a newer build is installed underneath
    Then it says a newer build is installed
    And the app is still open
