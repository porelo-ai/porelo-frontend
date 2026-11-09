# The Feature line is the report row: one short sentence, 70 characters at most,
# saying what this file tests. Run by tool/rehearse_window.sh against a rented host, never in the Build.
Feature: A move rehearsed in the window against a rented host

    # The host is set up and follows a test organization whose every role is one test person; this
    # window runs as that person, in a VM with no desktop. Each step checks on the host what the window
    # made happen there. PORELO_REHEARSAL_PROJECT names the project the organization put on the host.
    Background:
        Given the interface is running
        And the rehearsal names its host and project

    Scenario: the host the organization lists is connected from its card
        When I connect the host from the organization
        Then the host is answering through the window

    Scenario: the organization's machines list the host with the project it carries
        When I open the organization's machines
        Then the host is listed there with the project

    Scenario: the project on the host names each repository as the host carries it
        Given the host is connected from the organization
        When I open the project on the host
        Then each repository of the project says whether the host carries it, as the host says

    Scenario: work started from the project on the host runs there, named and with its model
        Given the host is connected from the organization
        When I start work on the first carried repository of the project
        Then the host runs that work, under the name and model the window showed

    Scenario: a start for every repository makes one task each and asks no sign-in twice
        Given the host is connected from the organization
        When I start work on every repository of the project at once
        Then the host runs one task for each carried repository

    Scenario: a task's push is reviewed, forwarded to the host's forge and built there
        Given the host is connected from the organization
        And a task of the project on the host has work waiting at its gate
        When I review that work at the gate
        Then the review names its commit and who made it
        When I forward it to a new branch of the rehearsal
        Then the host's forge has that branch at the reviewed commit
        And the task's tile says how its builds stand, as the host's runner says
