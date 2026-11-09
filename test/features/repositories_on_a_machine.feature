# The Feature line is the report row: one short sentence, 70 characters at most,
# saying what this file tests. It is the group name in every surface CI renders.
Feature: What a machine says of each repository of a project it holds

    Background:
        Given a backend with work on it
        And the app is running
        And I go to the work
        And I select the project {'checkout'}
        And the project {'checkout'} has the repositories {'checkout, payments-api, billing'}

    # A start in a repository the machine does not carry is refused there, so it is not offered.
    Scenario: a repository the machine does not carry says so, and its row starts nothing
        Given the machine says it does not carry the repository {'billing'}
        When I open {'checkout'} from the projects of this machine
        Then the repository {'billing'} says {'not carried here'}
        And the repository {'billing'} does not say {'on the machine'}
        And the repository {'billing'} cannot be started from its row

    Scenario: a repository the machine does not carry is not offered to start in
        Given the machine says it does not carry the repository {'billing'}
        When I start work in this project
        Then the repository {'billing'} is not offered to start in
        And the repository {'payments-api'} is offered to start in

    # Ahead with no count is not none ahead: work may wait to reach central.
    Scenario: ahead of central with no count reported is never none ahead
        Given the machine says the repository {'payments-api'} stands {'ahead'} against central with no count
        When I open {'checkout'} from the projects of this machine
        Then the repository {'payments-api'} says {'ahead of central, by how much not reported'}
        And the repository {'payments-api'} does not say {'0 commits'}

    Scenario: a central state not reported yet is never at central
        Given the machine says it carries the repository {'payments-api'}
        When I open {'checkout'} from the projects of this machine
        Then the repository {'payments-api'} says {'central: not reported'}
        And the repository {'payments-api'} does not say {'at central'}

    Scenario: a central state of a later Porelo is shown as it comes, never as at central
        Given the machine says the repository {'payments-api'} stands {'diverged'} against central with no count
        When I open {'checkout'} from the projects of this machine
        Then the repository {'payments-api'} says {'central: diverged'}
        And the repository {'payments-api'} does not say {'at central'}

    # The machine counts work this window may not list, as another person's.
    Scenario: work the machine counts as running is never said to be none
        Given the machine counts {'1'} running of {'1'} tasks in the repository {'billing'}
        When I open {'checkout'} from the projects of this machine
        Then the repository {'billing'} says {'1 of 1 task running'}
        And the repository {'billing'} does not say {'no task running'}
