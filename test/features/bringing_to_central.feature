# The Feature line is the report row: one short sentence, 70 characters at most,
# saying what this file tests. It is the group name in every surface CI renders.
Feature: A host's finished main brought to central from its project's page

    Background:
        Given a backend with work on it
        And the app is running
        And I go to the work
        And I select the project {'checkout'}
        And the project {'checkout'} has the repositories {'checkout, payments-api, billing'}

    # A release reaches others at once and cannot be called back: the commits are named, and nothing leaves before yes.
    Scenario: work ahead of central is brought there once the person agrees
        Given the machine says the repository {'payments-api'} is {3} commits ahead of central
        When I open {'checkout'} from the projects of this machine
        And I press {'Bring it to central…'}
        Then it says {'3 commits of payments-api'}
        And nothing was brought to central
        When I press {'Bring them to central'}
        Then central was asked for {'payments-api'}
        And it says {'Brought to central: payments-api'}
        And the repository {'payments-api'} says {'at central'}

    Scenario: work the person does not agree to bring stays on the host
        Given the machine says the repository {'payments-api'} is {3} commits ahead of central
        When I open {'checkout'} from the projects of this machine
        And I press {'Bring it to central…'}
        And I press {'Cancel'}
        Then nothing was brought to central
        And the repository {'payments-api'} says {'3 commits ahead of central'}

    Scenario: a host whose main is at central offers nothing to bring
        Given the machine says the repository {'payments-api'} stands {'up-to-date'} against central with no count
        When I open {'checkout'} from the projects of this machine
        Then the page offers no {'Bring it to central…'}

    # A refused token is the forge's answer: said as refused, never as a prompt that could not be shown.
    Scenario: a token the central forge refuses is said as refused
        Given the machine says the repository {'payments-api'} is {3} commits ahead of central
        And the central forge refuses the token
        When I open {'checkout'} from the projects of this machine
        And I press {'Bring it to central…'}
        And I press {'Bring them to central'}
        Then it says {'refused the token'}
        And it does not say {'Brought to central'}
        And the repository {'payments-api'} says {'3 commits ahead of central'}
