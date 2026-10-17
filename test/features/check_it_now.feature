# The Feature line is the report row: one short sentence, 70 characters at most,
# saying what this file tests. It is the group name in every surface CI renders.
Feature: Checking a followed project now, not at the next round

    # Without it, a project goes on saying what it said until the machine's next round, with nothing
    # to press. Checking now fetches the project's repository and asks each repository's upstream, and
    # says what came back.
    Background:
        Given a backend with work on it
        And the app is running
        And the project {'checkout'} has the repositories {'checkout, payments-api'}
        And the project {'checkout'} is followed from {'git@example.org:checkout.git'}
        And I go to the work
        And I select the project {'checkout'}

    Scenario: checking fetches the project and asks each repository, and says what it found
        When I check the project now
        Then the machine was asked to refresh {'checkout'}
        And the upstream was asked about {'checkout'}
        And it says {'Following, at c0ffee1'}
        And it says {'payments-api: 3 commits behind the upstream, as of now'}

    Scenario: while the machine fetches, the page says it is checking
        Given the machine takes its time to refresh
        When I check the project now
        Then it says {'checking…'}
        When the machine answers the refresh
        Then it does not say {'checking…'}
        And it says {'Following, at c0ffee1'}

    Scenario: a fetch that failed says why, in the machine's terms
        Given the next refresh finds {'VAULT_LOCKED'}
        When I check the project now
        Then it says {"This account's store is shut, and the repository needs a credential from it"}

    Scenario: a project this account no longer follows says so, rather than nothing
        Given the machine no longer follows {'checkout'}
        When I check the project now
        Then it says {'checkout is no longer followed here'}
