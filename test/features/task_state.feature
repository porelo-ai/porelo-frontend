# The Feature line is the report row: one short sentence, 70 characters at most,
# saying what this file tests. It is the group name in every surface CI renders.
Feature: What a piece of work is doing, and how long it has been

  Background:
    Given a backend with work on it
    And the app is running
    And I go to the work
    And I select the project {'checkout'}

  Scenario: work waiting on a person says so, and says what it is waiting on
    Given the work {'sokar-checkout-shell'} is waiting on {'api.example.test:443'}
    Then the work {'sokar-checkout-shell'} is shown as {'waiting'}
    And it says it is waiting on {'api.example.test:443'}

  Scenario: idle is told apart from finished
    Given the work {'sokar-checkout-shell'} is idle
    And the work {'sokar-checkout-migrate'} is dead
    Then the work {'sokar-checkout-shell'} is shown as {'Quiet'}
    And the work {'sokar-checkout-migrate'} is shown as {'Not running'}

  Scenario: how long it has been that way is answerable
    Given the work {'sokar-checkout-shell'} has been idle since {'40'} minutes ago
    Then the work {'sokar-checkout-shell'} is shown as {'Quiet for 40 minutes'}

  Scenario: work nothing can see is not reported as idle
    Given the work {'sokar-checkout-shell'} cannot be seen
    Then the work {'sokar-checkout-shell'} is shown as {'Running'}
    And the work {'sokar-checkout-shell'} is not shown as {'Quiet'}

  Scenario: a change of activity arrives without anybody asking for it
    Given the work {'sokar-checkout-shell'} is idle
    When the backend says it is waiting on {'api.example.test:443'}
    Then the work {'sokar-checkout-shell'} is shown as {'waiting'}

  # By name and destination, as the machine keeps them: never a token.
  Scenario: the credentials a task holds are shown with it
    Given the work {'sokar-checkout-migrate'} holds {'a-provider'} for {'weather'}
    When I select the work {'sokar-checkout-migrate'}
    And I open the selection
    Then the detail for {'sokar-checkout-migrate'} is shown
    And it says {'a-provider for weather, as SOKAR_TOKEN_A_PROVIDER'}

  Scenario: a credential a person granted says who the task acts as
    Given the work {'sokar-checkout-migrate'} holds {'jira'} for {'jira'}, granted by {'alice'} at {'2026-09-30T05:40:00Z'}
    When I select the work {'sokar-checkout-migrate'}
    And I open the selection
    Then it says {'jira for jira, as SOKAR_TOKEN_JIRA, granted by alice at 2026-09-30T05:40:00Z'}
