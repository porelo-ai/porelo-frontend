# The Feature line is the report row: one short sentence, 70 characters at most,
# saying what this file tests. Run by tool/e2e.sh with PORELO_E2E_NEW_PERSON=1 only.
Feature: A person new to Porelo, from an empty account, in the interface

  # The MVP's walk: one person, one machine, one agent, from nothing. Every step
  # is what the window offers; anything that needs a terminal or Porelo's own words is a defect of it.
  # One scenario, since it is one story: the interface keeps what each step did, as it would.
  Background:
    Given the account of a person new to Porelo, as it was given to them
    And the interface is running

  Scenario: a new person goes from an empty account to work on a repository of theirs
    When I add the machine I was given, knowing only how I log into it
    Then the machine is answering
    When I make the vault, choosing its passphrase in the terminal the interface opens
    Then the vault is open
    Given I have a repository {'my-first'} on that machine
    When I start work on it in default, as the window offers
    Then the work starts on {'my-first'}, which is in default now
    When I choose {'Claude'} as the agent
    Then I am offered to log in with {'Claude'}
