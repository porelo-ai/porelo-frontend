# The Feature line is the report row: one short sentence, 70 characters at most,
# saying what this file tests. It is the group name in every surface CI renders.
Feature: What each project is, and how far behind it has fallen

    Background:
        Given a backend with work on it
        And the app is running
        And I go to the work

    Scenario: a project says what it is and how much work it has
        Then the project {'checkout'} says {'1 of 2 running · guarded'}

    Scenario: a project whose environment is not prepared is marked
        Then the project {'unrecorded'} is marked as not prepared
        And the project {'checkout'} is not marked as not prepared

    Scenario: falling behind says by how much, and when that was measured
        Then the project {'checkout'} says {'3 behind, as of 20 minutes ago'}

    Scenario: never checked is not the same sentence as up to date
        Then the project {'unrecorded'} says {'Never checked against the upstream'}

    Scenario: a project that reaches nothing says that, rather than reporting zero
        Then the project {'billing'} says {'Not checked: this project reaches nothing'}

    Scenario: work waiting for review is said on the row
        Then the project {'checkout'} says {'2'} are waiting at the gate

    Scenario: a project nothing can act on is listed and marked, never left out
        Then the project {'unrecorded'} is listed
        And the project {'unrecorded'} is marked as unusable

    Scenario: what changed elsewhere arrives without anybody asking for it
        When work is started elsewhere in {'checkout'}
        Then the project {'checkout'} says {'2 of 3 running · guarded'}

    Scenario: selecting a project changes nothing about it
        When I select the project {'checkout'}
        Then nothing was asked of the backend about {'checkout'}

    Scenario: a count left over from an older measurement is not drawn as one
        Given the last check for {'billing'} failed, leaving a stale count
        And I go to the work
        Then the project {'billing'} says {'The last check did not work'}
        And the project {'billing'} does not say {'7 behind'}

    # **Prepared and up to date are different questions**:
    # `prepared` is true the whole time an image is stale, so work would start in something the
    # project file no longer describes and nothing would have mentioned it.
    Scenario: an environment built before the project file changed is marked
        Then the project {'billing'} is marked as stale
        And the project {'checkout'} is not marked as stale

    # Nothing knows either way there, and rebuilding for no reason is how a word stops being read.
    Scenario: an image that records nothing about itself is not called stale
        Given the project {'checkout'} records nothing about its image
        When the app is restarted
        And I go to the work
        Then the project {'checkout'} is not marked as stale

    # Nothing pushes the project list, so it is asked again: by hand, or on its own as often as set.
    Scenario: a project removed at the machine goes when every machine is asked again
        Given the project {'unrecorded'} is removed at the machine
        When I refresh every machine
        Then the project {'unrecorded'} is not listed

    Scenario: every machine is asked again on its own, as often as chosen
        Given the project {'unrecorded'} is removed at the machine
        When I choose to refresh automatically {'every 30 seconds'}
        And {31} seconds pass
        Then the project {'unrecorded'} is not listed

    Scenario: asking again on its own can be turned off, and that survives a restart
        Given the project {'unrecorded'} is removed at the machine
        When I choose to refresh automatically {'off'}
        And {120} seconds pass
        Then the project {'unrecorded'} is listed
        When the app is restarted
        Then refreshing automatically is off
