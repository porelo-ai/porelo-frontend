# The Feature line is the report row: one short sentence, 70 characters at most,
# saying what this file tests. It is the group name in every surface CI renders.
Feature: What the build of the work's push did, as the machine reads it

  Background:
    Given a backend with work on it
    And the app is running
    And I go to the work
    And I select the project {'checkout'}
    And I select the work {'porelo-checkout-shell'}

  Scenario: work no forge follows says nothing about builds
    Given no forge follows the builds of {'porelo-checkout-shell'}
    When I open the selection
    Then it does not say {'Builds'}

  Scenario: a machine older than builds says nothing about them, rather than none
    When I open the selection
    Then it does not say {'Builds'}
    And it does not say {'no push yet'}

  Scenario: a followed task with nothing pushed yet says so
    Given the builds of {'porelo-checkout-shell'} are read from {'github'}
    Then a tile says {'No build yet'}
    And a tile says {'no push yet; its builds are read from github'}

  Scenario: a build underway lists no jobs yet
    Given the builds of {'porelo-checkout-shell'} are read from {'github'}
    And the build of {'0123456789abcdef0123'} is {'running'}
    Then a tile says {'Build running'}
    When I open the selection
    Then it says {'no jobs yet'}

  Scenario: a failed build lists every job, and the log of the one that failed
    Given the builds of {'porelo-checkout-shell'} are read from {'github'}
    And the build of {'0123456789abcdef0123'} failed in {'Build / unit tests'} of {3} jobs
    Then a tile says {'Build failed'}
    And a tile says {'0123456789ab · 3 jobs, 1 failed'}
    When I open the selection
    Then it says {'Build / unit tests: failure, log in /porelo/files/build-0123456789ab-1.log'}
    And it says {'Job 2: success, no log here'}

  Scenario: a verdict the machine could not get says why
    Given the builds of {'porelo-checkout-shell'} are read from {'github'}
    And the build of {'0123456789abcdef0123'} is unknown because {'the vault is shut'}
    Then a tile says {'0123456789ab · the vault is shut'}

  Scenario: a verdict or a result this interface does not know is shown as it comes
    Given the builds of {'porelo-checkout-shell'} are read from {'github'}
    And the build of {'0123456789abcdef0123'} is {'waiting_for_runner'}
    Then a tile says {'Build: waiting_for_runner'}

  Scenario: a reader that does not work is said, whatever the builds hold
    Given the builds of {'porelo-checkout-shell'} are read from {'github'}
    And that reader does not work because {'not installed'}
    Then a tile says {'Builds not followed'}
    And a tile says {'not installed'}
