# The Feature line is the report row: one short sentence, 70 characters at most,
# saying what this file tests. It is the group name in every surface CI renders.
Feature: Trying a machine from the dialog, before it is watched

  Background:
    Given a backend with work on it
    And the app is running
    And I go to the work
    When I start watching another machine

  Scenario: a machine that answers says what it is, and nothing is left running
    When I choose {'Raise the forward for me'}
    And I say it is at {'user@build.example.test'}
    And its socket there is {'/run/user/1001/porelo/porelod.sock'}
    And I try the connection
    Then the trial says {'Reached Porelo 0.1.0-mock'}
    And the forward raised for the trial was taken down

  Scenario: a forward ssh cannot raise says what ssh said
    Given raising a forward will fail with {'Host key verification failed.'}
    When I choose {'Raise the forward for me'}
    And I say it is at {'user@build.example.test'}
    And its socket there is {'/run/user/1001/porelo/porelod.sock'}
    And I try the connection
    Then the trial says {'Host key verification failed.'}
    And the forward raised for the trial was taken down

  # The forward comes up either way; only connecting through it finds the far end empty.
  Scenario: a forward to a socket nobody serves points at the far end
    Given nothing answers on that machine
    When I choose {'Raise the forward for me'}
    And I say it is at {'user@build.example.test'}
    And its socket there is {'/run/user/1001/porelo/porelod.sock'}
    And I try the connection
    Then the trial says {'nothing answers at /run/user/1001/porelo/porelod.sock on that machine'}
    And the forward raised for the trial was taken down

  Scenario: a socket left empty is asked of the machine, shown filled in, and tried
    Given the account logs in as uid {1001}
    When I choose {'Raise the forward for me'}
    And I say it is at {'user@build.example.test'}
    And I try the connection
    Then the machine was asked who {'user@build.example.test'} logs in as
    And its socket there reads {'/run/user/1001/porelo/porelod.sock'}
    And the trial says {'Reached Porelo 0.1.0-mock'}

  Scenario: a socket left empty on a machine that cannot be asked says how to go on, and tries nothing
    When I choose {'Raise the forward for me'}
    And I say it is at {'user@build.example.test'}
    And I try the connection
    Then the trial says {'Could not log in to user@build.example.test to ask where Porelo is for you there'}
    And the trial says {'or type its socket'}
    And nothing was raised for the trial

  # ssh says the same words for a missing daemon and for another user's socket, so the login uid is asked.
  Scenario: a socket in another user's runtime directory is named as that, with the path meant
    Given nothing answers on that machine
    And the account logs in as uid {1000}
    When I choose {'Raise the forward for me'}
    And I say it is at {'user@build.example.test'}
    And its socket there is {'/run/user/1001/porelo/porelod.sock'}
    And I try the connection
    Then the trial says {'runtime directory (uid 1001)'}
    And the trial says {'Did you mean /run/user/1000/porelo/porelod.sock'}
    And starting Porelo there is not offered

  Scenario: a socket under the login's own uid still says that nothing answers
    Given nothing answers on that machine
    And the account logs in as uid {1001}
    When I choose {'Raise the forward for me'}
    And I say it is at {'user@build.example.test'}
    And its socket there is {'/run/user/1001/porelo/porelod.sock'}
    And I try the connection
    Then the trial says {'nothing answers at /run/user/1001/porelo/porelod.sock on that machine'}
    And starting Porelo there is offered
    When I turn the offer down
    Then nothing was started on that machine

  # ssh works and nothing serves: the one failure the dialog can answer rather than only describe.
  Scenario: a machine nobody serves is offered a start, and nothing runs until it is asked for
    Given nothing answers on that machine
    When I choose {'Raise the forward for me'}
    And I say it is at {'user@build.example.test'}
    And its socket there is {'/run/user/1001/porelo/porelod.sock'}
    And I try the connection
    Then starting Porelo there is offered
    And the question is asked in its own dialog
    And the question does not show the command it runs
    When I ask to see the command it runs
    Then the question shows {'setsid porelod'}
    And nothing was started on that machine
    When I start Porelo there
    Then the machine was asked to start {'setsid porelod'}
    And the trial says {'Reached Porelo'}

  Scenario: the offer is turned down and nothing is run
    Given nothing answers on that machine
    When I choose {'Raise the forward for me'}
    And I say it is at {'user@build.example.test'}
    And its socket there is {'/run/user/1001/porelo/porelod.sock'}
    And I try the connection
    And I turn the offer down
    Then starting Porelo there is not offered
    And nothing was started on that machine

  Scenario: a start that failed says what came back
    Given nothing answers on that machine
    And starting Porelo will fail with {'no porelod is installed there'}
    When I choose {'Raise the forward for me'}
    And I say it is at {'user@build.example.test'}
    And its socket there is {'/run/user/1001/porelo/porelod.sock'}
    And I try the connection
    And I start Porelo there
    Then the start says {'no porelod is installed there'}

  # The dialog shows what came back, and closing it must not lose a failure.
  Scenario: a start that failed in the dialog waits under what needs a person once it is closed
    Given nothing answers on that machine
    And starting Porelo will fail with {'no porelod is installed there'}
    When I choose {'Raise the forward for me'}
    And I say it is at {'user@build.example.test'}
    And its socket there is {'/run/user/1001/porelo/porelod.sock'}
    And I try the connection
    And I start Porelo there
    And I cancel the dialog
    And I go to what needs a person
    Then a failed operation waits saying {'no porelod is installed there'}

  # A forward that never came up is a different problem, and starting something cannot answer it.
  Scenario: a forward ssh could not raise is never offered a start
    Given raising a forward will fail with {'Host key verification failed.'}
    When I choose {'Raise the forward for me'}
    And I say it is at {'user@build.example.test'}
    And its socket there is {'/run/user/1001/porelo/porelod.sock'}
    And I try the connection
    Then starting Porelo there is not offered

  Scenario: a socket somebody else forwarded names no host to log into
    Given nothing answers on that machine
    When I choose {'Its socket is already forwarded'}
    And the forwarded socket is {'/tmp/porelod-remote.sock'}
    And I try the connection
    Then starting Porelo there is not offered

  Scenario: a machine that speaks something else says so
    Given the machine serves nothing this build knows
    When I choose {'Its socket is already forwarded'}
    And the forwarded socket is {'/tmp/porelod-remote.sock'}
    And I try the connection
    Then the trial says {'serves nothing this build understands'}

  Scenario: a socket already forwarded is tried without raising anything
    When I choose {'Its socket is already forwarded'}
    And the forwarded socket is {'/tmp/porelod-remote.sock'}
    And I try the connection
    Then the trial says {'Reached Porelo'}
    And nothing was raised for the trial

  Scenario: changing where it is takes the old answer away
    When I choose {'Raise the forward for me'}
    And I say it is at {'user@build.example.test'}
    And its socket there is {'/run/user/1001/porelo/porelod.sock'}
    And I try the connection
    And I say it is at {'user@other.example.test'}
    Then the trial says nothing
