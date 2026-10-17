# The Feature line is the report row: one short sentence, 70 characters at most,
# saying what this file tests. It is the group name in every surface CI renders.
Feature: Stopping, removing, renaming and recreating work, and what it costs

    Background:
        Given a backend with work on it
        And the app is running
        And I go to the work
        And I select the project {'checkout'}
        And I select the work {'porelo-checkout-shell'}

    Scenario: work holding commits that never reached the gate is refused, not removed
        Given removing will refuse because the work is held
        When I ask to remove the selected work
        And I confirm
        Then what is held is shown
        And the status line mentions {'holds work that never reached the gate'}
        When I choose {'Leave it alone'}
        Then the work {'porelo-checkout-shell'} is listed

    # What is held has no length limit, and the choice comes after it.
    Scenario: a long list of what is held still leaves the choice within reach
        Given removing will refuse because {60} commits are held
        When I ask to remove the selected work
        And I confirm
        And I choose {'Leave it alone'}
        Then the work {'porelo-checkout-shell'} is listed

    Scenario: what is held can be pushed to the mirror before it is removed
        Given removing will refuse because the work is held
        When I ask to remove the selected work
        And I confirm
        And I choose {'Push what it holds to the mirror, then remove it'}
        Then the removal asked to rescue what was held

    Scenario: what is held is discarded only when that is chosen in those words
        Given removing will refuse because the work is held
        When I ask to remove the selected work
        And I confirm
        And I choose {'Discard what it holds and remove it'}
        Then the removal asked to discard what was held

    Scenario: leaving a refusal alone touches nothing
        Given removing will refuse because the work is held
        When I ask to remove the selected work
        And I confirm
        And I choose {'Leave it alone'}
        Then nothing more was asked of the backend
        And the work {'porelo-checkout-shell'} is listed
        And the status line mentions {'nothing was touched'}

    Scenario: running work is stopped before it is removed, and stops being listed
        When I ask to remove the selected work
        And I confirm
        Then the stop asked for {'porelo-checkout-shell'}
        And the removal asked for {'porelo-checkout-shell'}
        And the status line mentions {'was removed'}
        And the status line mentions {'3 paths only it held went with it'}
        And the work {'porelo-checkout-shell'} is no longer listed

    # Asked while it still runs: rescue needs the container up, so stopping first would lose it.
    Scenario: running work that holds commits is asked about before anything stops it
        Given removing will refuse because the work is held
        When I ask to remove the selected work
        And I confirm
        Then what is held is shown
        And the work was never stopped

    # A task listed as stopped can be running again by the time the removal arrives.
    Scenario: a removal the machine says still runs is stopped, then removed
        Given the work {'porelo-checkout-shell'} has stopped
        And removing will refuse because the work still runs
        When I ask to remove the selected work
        And I confirm
        Then the stop asked for {'porelo-checkout-shell'}
        And the removal asked for {'porelo-checkout-shell'}

    Scenario: stopping keeps the work, to be started again
        When I stop the selected work
        Then the stop asked for {'porelo-checkout-shell'}
        And the work was not removed
        And the status line mentions {'It is kept, workspace and all'}
        And the work {'porelo-checkout-shell'} is listed

    Scenario: the confirmation names what is destroyed along with the work
        When I ask to remove the selected work
        Then the confirmation says {'exists nowhere else'}

    Scenario: an action the state does not allow is offered as unavailable, not hidden
        When I open the actions for {'porelo-checkout-shell'}
        Then the action {'Start it again'} is offered as unavailable

    Scenario: an action with no method behind it says so rather than going missing
        When I open the actions for {'porelo-checkout-shell'}
        Then the action {'Rename it'} is offered as unavailable

    Scenario: work carries a caption a person can change, beside its identity
        When I give this work something to read by {'schema migration, second attempt'}
        Then the work reads as {'schema migration, second attempt'}
        And its name is still shown as {'porelo-checkout-shell'}

    Scenario: the caption never becomes the identity
        When I give this work something to read by {'schema migration'}
        And I open the selection
        Then it says its name is {'porelo-checkout-shell'}

    Scenario: an empty caption takes it away rather than storing nothing
        Given this work already reads as {'schema migration'}
        When I give this work something to read by {''}
        Then the work reads as {'porelo-checkout-shell'}
        And the caption sent was empty

    Scenario: the dialog says the name will not move
        When I ask what this work should read as
        Then it says {'Its name stays porelo-checkout-shell'}

    Scenario: recreating says why it exists, and what it costs
        When I ask to recreate the selected work
        Then it says {'picks up a newly built environment'}
        And it says {'goes with it and exists nowhere else'}

    Scenario: recreating takes it down and starts the same work again
        When I ask to recreate the selected work
        And I agree to recreate it
        Then the removal asked for {'porelo-checkout-shell'}
        And the launch was called {'shell'}

    Scenario: work that holds unpushed commits stops the recreation, and says so
        Given removing will refuse because the work is held
        When I ask to recreate the selected work
        And I agree to recreate it
        Then what is held is shown
        And nothing was started

    # Recreated where it worked, not in whichever repository a start would pick.
    Scenario: recreating starts the same work again in the repository it worked in
        Given the project {'checkout'} has the repositories {'checkout, payments-api'}
        And the work {'porelo-checkout-shell'} works in the repository {'payments-api'}
        When I ask to recreate the selected work
        And I agree to recreate it
        Then the launch was in the repository {'payments-api'}
