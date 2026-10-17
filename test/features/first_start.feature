# The Feature line is the report row: one short sentence, 70 characters at most,
# saying what this file tests. It is the group name in every surface CI renders.
Feature: A first start led from a machine to a project to the first work

    # Decided: set up a machine (this computer or one over ssh), then a project
    # unless working without one, then start work. Once there is work, the window opens on it.
    Scenario: with no work anywhere, the work page leads through three steps
        Given a backend with nothing on it
        And the app is running
        Then the section shown is {'Work'}
        And the first step {'machine'} is done {true}
        And the first step {'project'} is done {false}
        And it says {'From a repository you have'}
        When I choose to work without a project first
        Then the first step {'project'} is done {true}
        And it says {'Start the first work'}

    Scenario: a machine that does not answer is the first step still to take
        Given a backend with nothing on it
        And the app is running
        When the tunnel drops
        Then the first step {'machine'} is done {false}
        And it says {'Set up a machine'}
        And it does not say {'Start the first work'}
        When enough time passes for another try
        Then the first step {'machine'} is done {true}

    Scenario: once there is work, the window shows it rather than the first steps
        Given a backend with work on it
        And the app is running
        Then it does not say {'Three steps, and the first work runs'}
