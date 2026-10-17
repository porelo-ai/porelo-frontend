# The Feature line is the report row: one short sentence, 70 characters at most,
# saying what this file tests. It is the group name in every surface CI renders.
Feature: Running long operations without blocking the frame

    Background:
        Given a backend with work on it
        And the app is running
        And I go to the work
        And I select the project {'checkout'}

    Scenario: the frame stays usable while a long operation runs
        When I choose the command {'Show what this project would open, creating nothing'}
        And I close what is open
        And I select the project {'checkout'}
        Then the work {'porelo-checkout-shell'} is listed
        And the operation is still running

    Scenario: output goes to the operation and disturbs nothing else
        When I choose the command {'Show what this project would open, creating nothing'}
        And the operation prints {'Building the image'}
        Then the operation shows {'Building the image'}
        When I close what is open
        Then {'Building the image'} is nowhere on the frame

    Scenario: an operation can be left and watched again without stopping it
        When I choose the command {'Show what this project would open, creating nothing'}
        And the operation prints {'step one'}
        And I close what is open
        And the operation prints {'step two'}
        And I show what this session has run
        And I open the last operation
        Then the operation shows {'step one'}
        And the operation shows {'step two'}
        And the operation is still running

    Scenario: everything this session ran is listed afterwards with its outcome
        When I choose the command {'Show what this project would open, creating nothing'}
        And the operation finishes
        And I close what is open
        And I show what this session has run
        Then the record shows {'would open'}
        And the record shows {'Finished.'}

    Scenario: failure is reported where success would have been, with the output that explains it
        When I choose the command {'Show what this project would open, creating nothing'}
        And the operation prints {'could not read project.yml'}
        And the operation fails
        And I close what is open
        And I show what this session has run
        Then the record shows {'exited with code 1'}
        And the record marks it as failed
        When I open the last operation
        Then the operation shows {'could not read project.yml'}

    Scenario: a run stopped by its own time limit is not read as a run that went wrong
        When I choose the command {'Show what this project would open, creating nothing'}
        And the operation prints {'agent: editing lib/money.dart'}
        And the operation runs out of time
        And I close what is open
        And I show what this session has run
        Then the record shows {'ran out of the time it was given'}
        When I open the last operation
        Then the operation shows {'agent: editing lib/money.dart'}

    Scenario: a run refused before it began says nothing was created, not that it failed
        When I choose the command {'Show what this project would open, creating nothing'}
        And the run is refused before it begins
        And I close what is open
        And I show what this session has run
        Then the record shows {'Nothing ran, and nothing was created'}

    # Somebody who closed the view before it failed has not seen it, and nothing else would say so.
    Scenario: a failure nobody watched waits under what needs a person until it is opened
        When I choose the command {'Show what this project would open, creating nothing'}
        And the operation prints {'could not read project.yml'}
        And I close what is open
        And the operation fails
        And I go to what needs a person
        Then a failed operation waits saying {'would open'}
        And the count of what needs a person is {'1 need you'}
        When I open the failed operation from what needs a person
        Then the operation shows {'could not read project.yml'}
        When I close what is open
        And I go to what needs a person
        Then no failed operation waits
        And the count of what needs a person is {'nothing needs you'}

    Scenario: a failure watched as it happened does not wait
        When I choose the command {'Show what this project would open, creating nothing'}
        And the operation fails
        And I close what is open
        And I go to what needs a person
        Then no failed operation waits

    Scenario: an operation that finished never waits
        When I choose the command {'Show what this project would open, creating nothing'}
        And I close what is open
        And the operation finishes
        And I go to what needs a person
        Then no failed operation waits

    Scenario: a failure opened from the session record no longer waits
        When I choose the command {'Show what this project would open, creating nothing'}
        And I close what is open
        And the operation fails
        And I show what this session has run
        And I open the last operation
        And I close what is open
        And I go to what needs a person
        Then no failed operation waits

    # What ran is kept in a file, so closing the window does not lose it.
    Scenario: what was run is listed again after a restart, marked as earlier
        When I choose the command {'Show what this project would open, creating nothing'}
        And the operation finishes
        And I close what is open
        And the app is restarted
        And I show what this session has run
        Then the record shows {'would open'}
        And the record shows {'earlier'}

    Scenario: a failure nobody opened still waits after a restart
        When I choose the command {'Show what this project would open, creating nothing'}
        And I close what is open
        And the operation fails
        And the app is restarted
        And I go to what needs a person
        Then a failed operation waits saying {'would open'}

    Scenario: the record says where it is kept
        When I show what this session has run
        Then the record shows {'Kept for 30 days in'}

    Scenario: the file of what was run is opened from the finder
        When I choose the command {'Open the file of everything that was run'}
        Then the file of what was run was opened

    # A repository's egress is added to the project's. The project's dry run is the plan
    # every repository gets; naming one shows what it adds.
    Scenario: what one repository would open is shown on its own, creating nothing
        Given the project {'checkout'} has the repositories {'checkout, payments-api'}
        When I show what the repository {'payments-api'} would open
        Then the operation is open
        And the launch was a dry run in the repository {'payments-api'}

    Scenario: what the project would open names no repository
        When I choose the command {'Show what this project would open, creating nothing'}
        Then the launch was a dry run in no repository

