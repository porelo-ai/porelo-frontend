# The Feature line is the report row: one short sentence, 70 characters at most,
# saying what this file tests. It is the group name in every surface CI renders.
Feature: Working inside a container by hand, locally or over ssh

    Background:
        Given a backend with work on it
        And the app is running
        And I go to the work
        And I select the project {'billing'}
        And I select the work {'porelo-billing-shell'}

    Scenario: a session is one action from where the work is listed
        When I work in it by hand
        Then the session runs {'porelo task attach porelo-billing-shell'}

    Scenario: a machine reached over ssh runs the same verb, through a terminal of its own
        When I start watching another machine
        And I choose {'Raise the forward for me'}
        And I say it is called {'the build machine'}
        And I say it is at {'user@build.example.test'}
        And its socket there is {'/run/user/1001/porelo/porelod.sock'}
        And I watch it
        And I switch to the machine {'the build machine'}
        And I select the project {'billing'}
        And I select the work {'porelo-billing-shell'}
        And I work in it by hand
        Then the session runs {'ssh -t user@build.example.test porelo task attach porelo-billing-shell'}

    Scenario: what the far end prints is what is on the screen
        When I work in it by hand
        And the session prints {'root@porelo-billing-shell:/work#'}
        Then the session shows {'root@porelo-billing-shell:/work#'}

    Scenario: what is typed reaches the far end
        When I work in it by hand
        And I type {'ls -l'} into the session
        Then the session was sent {'ls -l'}

    # The same work that may not be widened, and deliberately so: the class governs egress — what
    # resolves and what leaves — and a person typing is neither. Offline is precisely the project
    # where somebody has to work by hand, because the agent reaches nothing.
    Scenario: an offline project may be worked in by hand, though it may not be widened
        When I open the command finder
        Then the command {'Let this work reach something new'} is offered as unavailable
        When I work in it by hand
        Then the session runs {'porelo task attach porelo-billing-shell'}

    # Once refused here, on the strength of "the agent is the main process, so there is
    # no session to attach to". Wrong: `AGENT` and `SHELL` are the same task — same container, same
    # egress, same gate — and attaching starts its own multiplexer by `podman exec`, which does not
    # care what the main process is. The refusal took the action away from the commonest kind of
    # task there is.
    Scenario: work an agent is driving can be worked in by hand like any other
        Given I select the project {'checkout'}
        And I select the work {'porelo-checkout-shell'}
        When I work in it by hand
        Then the session runs {'porelo task attach porelo-checkout-shell'}

    # Against work whose mode nothing recorded, deliberately: nothing else can take the action
    # away, so what is measured is the running check on its own. A scenario against a stopped
    # unattended run passed with that check deleted — the agent rule was doing the work.
    Scenario: work that has stopped has no session, and points at starting it again
        When I select the work {'porelo-billing-audit'}
        And the work {'porelo-billing-audit'} is dead
        And I open the command finder
        Then the command {'Work in it by hand'} is unavailable because {'Starting it again brings back the workspace'}

    # Opened where it was asked for and kept there: going elsewhere and back finds it as it was.
    Scenario: a session stays where it was opened, and going elsewhere and back finds it there
        When I work in it by hand
        Then the session is on screen
        And the work pane is not shown
        When I go to what needs a person
        Then the session is not on screen
        When I go to the place {'work'}
        Then the session is on screen

    Scenario: leaving a session puts somebody back where they were, with the same work selected
        When I work in it by hand
        And I leave the session
        Then the work {'porelo-billing-shell'} is still selected

    # Found by asking where the key went rather than by assuming: the frame's `Escape` closed the
    # pane and the far end never saw it, which would have made `vim` unusable inside a session.
    Scenario: Escape belongs to what is running, and never closes the session
        When I work in it by hand
        And I close what is open
        Then the session is on screen
        And {1} sessions are open

    # Decided: one at a time. A second way in leaves the first; its work carries on.
    # A session opened from the work page stays on it until it is left: work has one page now, so
    # another session is opened from a tile once this one is left.
    Scenario: a session left and another opened from a tile keeps one open, and stops no work
        When I work in it by hand
        And I leave the session
        And I work in {'porelo-billing-audit'} by hand from its tile
        Then {1} sessions are open
        And the session on screen is {'porelo-billing-audit'}
        And the first session was left
        And the work was never stopped
        When I select the project {'billing'}
        Then the session is not on screen

    # One container holds one session, so asking again returns to the one that is there. A second
    # way in to the same work would draw the same screen twice and let somebody type into either.
    Scenario: going back to the work finds the same session, not a second one
        When I work in it by hand
        And I go to what needs a person
        And I go to the place {'work'}
        Then {1} sessions are open
        And only one terminal was ever opened
        And the session on screen is {'porelo-billing-shell'}

    Scenario: the screen says that closing the window leaves the session running
        When I work in it by hand
        Then it says {'Closing this window leaves the session running'}

    # The figure is Porelo's, pinned in the image rather than left to tmux's default, so coming back
    # can say what it shows instead of leaving somebody to guess whether a quiet hour is missing.
    Scenario: coming back says how much of the missed time it can show
        When I work in it by hand
        Then it says {'the last 10000 lines and no more'}

    Scenario: a session the machine would not open says so, without claiming the work stopped
        When I work in it by hand
        And the session ends with {69}
        Then it says {'The machine would not open a session here'}
        And the work was never stopped

    Scenario: a connection that never happened is told apart from work that refused
        When I start watching another machine
        And I choose {'Raise the forward for me'}
        And I say it is called {'the build machine'}
        And I say it is at {'user@build.example.test'}
        And its socket there is {'/run/user/1001/porelo/porelod.sock'}
        And I watch it
        And I switch to the machine {'the build machine'}
        And I select the project {'billing'}
        And I select the work {'porelo-billing-shell'}
        And I work in it by hand
        And the session ends with {255}
        Then it says {'The connection to the build machine failed'}

    Scenario: leaving a session closes the way in and stops nothing
        When I work in it by hand
        And I leave the session
        Then no session is open
        And the work was never stopped

    Scenario: somebody who typed exit is not told that anything went wrong, and is taken back to the work
        When I work in it by hand
        And the session ends with {0}
        Then it says {'The session has ended. The work is where you left it'}
        And it does not say {'Closing this window leaves the session running'}
        When enough time passes to go back
        Then no session is open
