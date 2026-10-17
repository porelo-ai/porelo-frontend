# The Feature line is the report row: one short sentence, 70 characters at most,
# saying what this file tests. It is the group name in every surface CI renders.
Feature: What a project may reach, and no longer following one

    Background:
        Given a backend with work on it
        And the app is running
        And I go to the work
        And I select the project {'checkout'}

    Scenario: what the work may reach says where each host came from
        When I open what this project may reach
        Then it shows {'api.anthropic.com'} granted by {'agent an-agent'}
        And it shows {'pub.dev'} granted by {'set dart-packages'}

    Scenario: what is asked for and refused is told apart from what nobody added
        When I open what this project may reach
        Then it says {'telemetry.example.test'} is refused

    Scenario: a set says which hosts it grants, because the name alone does not
        When I open what this project may reach
        And I look inside the set {'Container registries'}
        Then it lists {'quay.io'}

    # Walk 10: project.yml in the repository is the one place it is changed.
    Scenario: what a project may reach is shown, and said to be changed only in its repository
        When I open what this project may reach
        Then it says {'under egress; a machine following it takes the change'}
        And it does not say {'Make this change'}

    Scenario: a project that declares no egress at all is not offered it
        When I select the project {'billing'}
        And I open the command finder
        Then the command {'What this project may reach'} is offered as unavailable

    # A repository may declare egress of its own, and it is added to the project's, never in place of
    # it. So a repository's view is the project's and its own together, its own marked.
    Scenario: what a repository adds is shown on top of what every repository gets, and marked
        Given the project {'checkout'} has the repositories {'checkout, payments-api'}
        And the repository {'payments-api'} adds {'api.stripe.com'}
        When I select the project {'checkout'}
        And I open what the repository {'payments-api'} may reach
        Then it says {'checkout · payments-api'}
        And it says {'github.com'}
        And {'api.stripe.com'} is marked as added by the repository
        And {'github.com'} is not marked as added by the repository
        And egress was asked about the repository {'payments-api'}

    Scenario: choosing sets one at a time is explained, not merely how it works
        When I select the project {'checkout'}
        And I open what this project may reach
        Then it says {'ones installed later'}

    # A project exists on a machine because the machine follows its repository, so removing it is
    # stopping following. It refuses rather than deciding, which is why every scenario here is about
    # what it did *not* do.
    Scenario: what would go is shown, and asking removes nothing
        When I ask to stop following this project
        Then it says {'This stops following checkout'}
        And nothing was removed

    # The project is its repository, which is not on this machine. A confirmation that did not say so
    # would read as deleting the project itself.
    Scenario: the repository is said to be untouched, and following it again brings it back
        When I ask to stop following this project
        Then it says {'Its repository is not touched'}
        And it says {'Following its repository again brings it back'}

    Scenario: agreeing is a second act, and it says what is still there afterwards
        When I ask to stop following this project
        And I agree to stop following it
        Then following stopped for {'checkout'}
        And it says {'no longer followed here'}
        And nothing was forced

    Scenario: commits nobody reviewed stop it, and say where they exist
        Given stopping following will refuse because {'HOLDS_WORK'}
        When I ask to stop following this project
        And I agree to stop following it
        Then it says {'nobody has reviewed it'}
        And it says {'in the mirror and nowhere else'}
        And nothing was forced

    Scenario: running work stops it, and is not told the same way
        Given stopping following will refuse because {'TASKS_RUNNING'}
        When I ask to stop following this project
        And I agree to stop following it
        Then it says {'Work is still running'}
        And it says {'cut off where it stands'}

    Scenario: going past a refusal is a second decision, and is what carries force
        Given stopping following will refuse because {'HOLDS_WORK'}
        When I ask to stop following this project
        And I agree to stop following it
        And I agree to stop following it
        Then it was forced
        And it says {'is gone'}

    # It takes the project's name, and with force a project nothing follows is swept rather than
    # refused — so what tasks left behind can still be cleared away.
    Scenario: a project this machine does not follow can still be cleared away
        When I select the project {'unrecorded'}
        And I open the command finder
        Then the command {'Stop following this project'} is offered

    # A project from before projects were followed keeps the path the old registry recorded, and the
    # machine refuses every call about it. It is listed for what is left of it, and nothing else.
    Scenario: a project left from before following offers nothing but clearing it away
        Given the project {'checkout'} is left over, followed by nothing
        When I select the project {'checkout'}
        And I open the command finder
        Then the command {'Review what is waiting at the gate'} is unavailable because {'not a project this machine follows'}
        And the command {'Build the environment for this project'} is unavailable because {'not a project this machine follows'}
        And the command {'Stop following this project'} is offered

    Scenario: a project the machine follows nothing by is said to be so, and nothing goes
        Given the project {'checkout'} is left over, followed by nothing
        And the machine follows nothing called it
        When I ask to stop following this project
        Then it says {'Nothing follows checkout here'}
        And it says {'Nothing was removed'}

