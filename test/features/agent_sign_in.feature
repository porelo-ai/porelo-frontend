# The Feature line is the report row: one short sentence, 70 characters at most,
# saying what this file tests. It is the group name in every surface CI renders.
Feature: Signing the agent in before work starts on its machine

    Background:
        Given a backend with work on it
        And the app is running
        And I go to the work
        And I select the project {'checkout'}

    # Every answer but signed in holds the start: one this build does not know among them.
    Scenario Outline: an agent the machine does not read as signed in starts nothing
        Given the machine says {'an-agent'} is {<state>}
        When I start work in this project
        And I call it {'schema-work'}
        And I choose the agent {'An Agent'}
        And I start it
        Then starting is not offered yet
        And nothing was started
        Examples:
            | state            |
            | 'NOT_SIGNED_IN'  |
            | 'SIGNING_IN'     |
            | 'VAULT_SHUT'     |
            | 'CANNOT_SIGN_IN' |
            | 'HALF_SIGNED_IN' |

    # Not read is never fine: a refusal or a lost connection holds the start as a missing sign-in does.
    Scenario Outline: a machine that cannot say whether the agent is signed in starts nothing
        Given the machine says {'an-agent'} is {'SIGNED_IN'}
        And asking whether agents are signed in fails with {<how>}
        When I start work in this project
        And I call it {'schema-work'}
        And I choose the agent {'An Agent'}
        And I start it
        Then starting is not offered yet
        And nothing was started
        Examples:
            | how                 |
            | 'a refusal'         |
            | 'a lost connection' |

    Scenario Outline: a sign-in that ends before the agent is signed in starts nothing
        Given the machine says {'an-agent'} is {'NOT_SIGNED_IN'}
        When I start work in this project
        And I call it {'schema-work'}
        And I choose the agent {'An Agent'}
        And I press {'Sign in'}
        And I close the terminal of the sign-in
        And the sign-in ends as {<end>}
        And I start it
        Then starting is not offered yet
        And nothing was started
        Examples:
            | end             |
            | 'NOT_SIGNED_IN' |
            | 'VAULT_SHUT'    |
            | 'SIGNING_UP'    |
            | 'cut'           |

    # Signed in, whether work can start is asked again, and the start stays the person's press.
    Scenario: once signed in nothing starts by itself, and starting is offered
        Given the machine says {'an-agent'} is {'NOT_SIGNED_IN'}
        When I start work in this project
        And I call it {'schema-work'}
        And I choose the agent {'An Agent'}
        And I press {'Sign in'}
        And I close the terminal of the sign-in
        And the sign-in ends as {'SIGNED_IN'}
        Then nothing was started
        And starting is offered

    # The machine's answer to whether work can start wins for a start.
    Scenario: signed in while the machine still says the credential is missing starts nothing
        Given the machine says {'an-agent'} is {'NOT_SIGNED_IN'}
        And the vault holds no credential for what a run would use
        When I start work in this project
        And I call it {'schema-work'}
        And I choose the agent {'An Agent'}
        And I press {'Sign in'}
        And I close the terminal of the sign-in
        And the sign-in ends as {'SIGNED_IN'}
        And I start it
        Then starting is not offered yet
        And nothing was started

    Scenario: a sign-in that runs already is waited on, and its own terminal opened, never a second
        Given the machine says {'an-agent'} is {'SIGNING_IN'}
        When I start work in this project
        And I choose the agent {'An Agent'}
        Then the sign-in is waited on
        When I press {'Sign in'}
        Then the terminal of {'porelo-login-an-agent'} is open over the form
        And the machine was asked to start {0} sign-ins

    Scenario: a sign-in the machine finds running is opened and waited on, and not started again
        Given the machine says {'an-agent'} is {'NOT_SIGNED_IN'}
        And the machine answers a sign-in start with {'porelo-login-an-agent'} running already
        When I start work in this project
        And I choose the agent {'An Agent'}
        And I press {'Sign in'}
        Then the terminal of {'porelo-login-an-agent'} is open over the form
        And the sign-in is waited on
        When I close the terminal of the sign-in
        And I press {'Sign in'}
        Then the terminal of {'porelo-login-an-agent'} is open over the form
        And the machine was asked to start {1} sign-ins

    # Leaving drops only the wait: the login task is a task of its own, and goes on.
    Scenario Outline: leaving the form during a sign-in starts nothing and leaves the login task
        Given the machine says {'an-agent'} is {'NOT_SIGNED_IN'}
        When I start work in this project
        And I call it {'schema-work'}
        And I choose the agent {'An Agent'}
        And I press {'Sign in'}
        And I close the terminal of the sign-in
        And I leave the start form by {<how>}
        And the sign-in ends as {'SIGNED_IN'}
        Then nothing was started
        And the login task was not stopped
        And it says {'The sign-in to An Agent goes on in its own task'}
        Examples:
            | how           |
            | 'Escape'      |
            | 'the barrier' |
            | 'Not now'     |

    Scenario: ending the sign-in stops its login task, and nothing starts
        Given the machine says {'an-agent'} is {'NOT_SIGNED_IN'}
        When I start work in this project
        And I call it {'schema-work'}
        And I choose the agent {'An Agent'}
        And I press {'Sign in'}
        And I close the terminal of the sign-in
        And I press {'End the sign-in'}
        And the sign-in ends as {'NOT_SIGNED_IN'}
        And I start it
        Then the login task {'porelo-login-an-agent'} was stopped
        And starting is not offered yet
        And nothing was started

    # The form keeps the machine it was opened on: the sign-in, its terminal and the start all go there.
    Scenario: a sign-in goes to the machine its form was opened on, not to one chosen meanwhile
        Given the machine says {'an-agent'} is {'NOT_SIGNED_IN'}
        And the machine {'elsewhere'} has sign-ins of its own
        When I watch another machine called {'elsewhere'}
        And I go to the work
        And I select the project {'checkout'}
        And I start work in this project
        And the machine {'elsewhere'} is chosen behind the form
        And I call it {'schema-work'}
        And I choose the agent {'An Agent'}
        And I press {'Sign in'}
        Then the terminal of the sign-in is on the machine its form was opened on
        When I close the terminal of the sign-in
        And the sign-in ends as {'SIGNED_IN'}
        And I start it
        Then the start reached only the machine its form was opened on
        And no sign-in reached the machine {'elsewhere'}

    # A start refused when the sign-in went missing meanwhile is that start's failure, never sent again.
    Scenario: a start that fails while the agent reads not signed in offers the sign-in, and is not sent again
        Given the machine says {'an-agent'} is {'SIGNED_IN'}
        When I start work in this project
        And I call it {'schema-work'}
        And I choose the agent {'An Agent'}
        And I start it
        And the machine says {'an-agent'} is {'NOT_SIGNED_IN'}
        And the machine refuses the start as {'NOT_READY'}
        And I press {'Sign in'}
        Then the machine was asked to start {1} sign-ins
        And one start was sent

    Scenario: the sign-in a failed start offers is reached from the command finder too
        Given the machine says {'an-agent'} is {'SIGNED_IN'}
        When I start work in this project
        And I call it {'schema-work'}
        And I choose the agent {'An Agent'}
        And I start it
        And the machine says {'an-agent'} is {'NOT_SIGNED_IN'}
        And the machine refuses the start as {'NOT_READY'}
        And I choose the command {'Sign in'}
        Then the machine was asked to start {1} sign-ins
        And one start was sent

    # Leaving drops only the wait, as leaving the form does: the login task goes on.
    Scenario: leaving the failed start's view drops the wait on its sign-in and leaves the login task
        Given the machine says {'an-agent'} is {'SIGNED_IN'}
        When I start work in this project
        And I call it {'schema-work'}
        And I choose the agent {'An Agent'}
        And I start it
        And the machine says {'an-agent'} is {'NOT_SIGNED_IN'}
        And the machine refuses the start as {'NOT_READY'}
        And I press {'Sign in'}
        And I close the terminal of the sign-in
        Then the sign-in is waited on
        When I close what is open
        Then the sign-in is no longer waited on
        And the login task was not stopped
