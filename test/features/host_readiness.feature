# The Feature line is the report row: one short sentence, 70 characters at most,
# saying what this file tests. It is the group name in every surface CI renders.
Feature: Checking whether a machine can run work at all

    Background:
        Given a backend with work on it
        And the app is running
        And I go to the work

    Scenario: whether this machine can run anything is one action away
        When I check whether this machine can run anything
        Then it says {'This machine can run work. Nothing is missing.'}

    # Every one of these fails far from its cause. Until it was on the wire, somebody learned about
    # them by starting work and watching it behave strangely.
    Scenario: something missing is named, with what to do about it
        Given the machine is missing {'nft'} because {'no nftables binary on PATH'}
        When I check whether this machine can run anything
        Then it says {'This machine cannot run work: one thing it needs is missing.'}
        And it says {'no nftables binary on PATH'}
        And it says {'install nftables'}

    # DEGRADED and UNKNOWN leave a machine running tasks. Rounding either up to "fine" hides the
    # thing somebody would want to know before wondering why a run behaved oddly.
    Scenario: a machine that runs work with something worth knowing is not called fine
        Given the machine is degraded at {'rootless network backend'} because {'slirp4netns rather than pasta'}
        When I check whether this machine can run anything
        Then it says {'This machine runs work. One thing is worth knowing about.'}
        And it says {'slirp4netns rather than pasta'}

    # Its own answer rather than the good case: a probe that guesses well is indistinguishable from
    # one that works.
    Scenario: a check that could not be established says so rather than passing
        Given the machine cannot establish {'SELinux policy'}
        When I check whether this machine can run anything
        Then it says {'could not be established'}
        And it says {'This machine runs work. One thing is worth knowing about.'}

    Scenario: the same check can be run again on demand
        When I check whether this machine can run anything
        And I check the machine again
        Then the machine was asked twice whether it can run anything

    # Preparing a machine means installing packages and writing under /etc, which is root on the
    # node — and a machine that is not ready usually has no daemon to ask in the first place.
    Scenario: nothing here offers to fix the machine, and says so
        When I check whether this machine can run anything
        Then it says {'Nothing here installs or configures anything'}

    Scenario: a daemon too old to answer says so rather than showing a machine with nothing wrong
        Given the machine cannot answer whether it can run anything
        When I check whether this machine can run anything
        Then it says {'this backend has no Doctor'}
