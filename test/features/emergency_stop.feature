# The Feature line is the report row: one short sentence, 70 characters at most,
# saying what this file tests. It is the group name in every surface CI renders.
Feature: Stopping everything on a machine, and naming what survives

    Background:
        Given a backend with work on it
        And the app is running
        And I go to the work

    Scenario: the way to stop everything is on screen without opening anything
        Then stopping everything is offered on the frame

    Scenario: it is reachable by name as well
        When I open the command finder
        Then the command finder names {'Stop everything on this machine'}

    Scenario: it never stops anything on the first press
        When I ask to stop everything
        Then nothing has been stopped
        And it says {'This would stop the 3 pieces of work that are running'}

    Scenario: leaving is the default, so a stray Return carries nothing
        When I ask to stop everything
        Then leaving it running is the default

    Scenario: agreeing stops everything and says what state the machine is in
        When I ask to stop everything
        And I agree to stop everything
        Then it says {'Stopped the 3 that were running. Nothing was removed.'}
        And it says {'exactly where it was'}

    Scenario: the way back is named, not left to be worked out
        When I ask to stop everything
        And I agree to stop everything
        Then it says how to get back to work

    Scenario: a helper that outlived its stop is named, never counted
        Given one helper will outlive the stop
        When I ask to stop everything
        And I agree to stop everything
        Then it names the helper {'porelo-checkout-shell-gate (pid 4711)'}
        And it says {'killed on the machine by hand'}

    Scenario: losing the machine mid-stop says nothing was stopped
        Given the backend will refuse to stop everything
        When I ask to stop everything
        And I agree to stop everything
        Then it says {'Nothing was stopped, and work is still running'}

    Scenario: what was stopped is named, because the name is how it comes back
        When I ask to stop everything
        And I agree to stop everything
        Then it names the work {'porelo-checkout-shell'} among what was stopped

    Scenario: a preview promises nothing about what will survive
        When I ask to stop everything
        Then it does not claim everything will stop cleanly

    Scenario: the stop for every machine is on the rail, and it asks first
        When I ask to stop everything on every machine
        Then nothing has been stopped
        And it says {'Stop everything on every machine?'}

    Scenario: agreeing stops every machine, and says what survived on each
        When I watch another machine called {'elsewhere'}
        And I ask to stop everything on every machine
        And I agree to stop everything everywhere
        Then every machine was stopped
        And it says {'Nothing was removed'}
