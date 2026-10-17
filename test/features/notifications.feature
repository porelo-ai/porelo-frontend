# The Feature line is the report row: one short sentence, 70 characters at most,
# saying what this file tests. It is the group name in every surface CI renders.
Feature: Telling somebody who is not looking at the window

    Background:
        Given a backend with work on it
        And the app is running
        And I go to the work
        And I select the project {'checkout'}

    Scenario: a waiting decision reaches somebody who is not looking at the window
        When work is blocked reaching {'api.example.test:443'}
        Then somebody is told {'is asking to reach api.example.test:443'}
        And it was told as something that cannot wait

    # Every machine is watched from the moment it is added, not only those there at the start.
    Scenario: a question on a machine added later reaches somebody too
        When I watch another machine called {'elsewhere'}
        And work elsewhere is blocked reaching {'api.example.test:443'}
        Then somebody is told {'is asking to reach api.example.test:443'}

    Scenario: the same question is never raised twice
        When work is blocked reaching {'api.example.test:443'}
        And work is blocked reaching {'api.example.test:443'}
        Then somebody was told exactly {'1'} time

    Scenario: finishing is told apart from failing
        When I choose the command {'Show what this project would open, creating nothing'}
        And the operation finishes
        Then somebody is told {'That is done'}
        When I choose the command {'Show what this project would open, creating nothing'}
        And the operation fails
        Then somebody is told {'That did not work'}

    Scenario: acting on it opens the work it came from
        When I choose the command {'Show what this project would open, creating nothing'}
        And the operation finishes
        And I close what is open
        And somebody acts on what they were told
        Then the operation is open

    Scenario: a project that has been turned off says nothing
        When I select the project {'checkout'}
        And I stop being told about this project
        And work is blocked reaching {'api.example.test:443'}
        Then nobody was told anything

    Scenario: a project that is turned off says so where it is listed
        When I select the project {'checkout'}
        And I stop being told about this project
        Then the project {'checkout'} is marked as silent

    Scenario: turning a project off does not silence the others
        When I select the project {'checkout'}
        And I stop being told about this project
        And work in {'billing'} is blocked reaching {'api.example.test:443'}
        Then somebody is told {'is asking to reach api.example.test:443'}
