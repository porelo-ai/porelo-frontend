# The Feature line is the report row: one short sentence, 70 characters at most,
# saying what this file tests. It is the group name in every surface CI renders.
Feature: Signing the agent in before work starts on its machine

    Background:
        Given a backend with work on it
        And the app is running
        And I go to the work
        And I select the project {'checkout'}

    # Every answer but signed in holds the start: a shut vault and one this build does not know among them.
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
            | 'VAULT_LOCKED'   |
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
            | end                  |
            | 'NOT_SIGNED_IN'      |
            | 'NOTHING_TO_COLLECT' |
            | 'VAULT_LOCKED'       |
            | 'TIMED_OUT'          |
            | 'SIGNING_UP'         |
            | 'cut'                |

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

    # The machine cannot say of an agent whose own provider it cannot use: the start settles the credential, so its answer decides.
    Scenario: an agent the machine cannot say of starts where the machine says work can start
        Given the machine says {'an-agent'} is {'CANNOT_SAY'}
        When I start work in this project
        And I call it {'schema-work'}
        And I choose the agent {'An Agent'}
        Then starting is offered
        And nothing was started

    Scenario: an agent the machine cannot say of starts nothing while the machine says the credential is missing
        Given the machine says {'an-agent'} is {'CANNOT_SAY'}
        And the vault holds no credential for what a run would use
        When I start work in this project
        And I call it {'schema-work'}
        And I choose the agent {'An Agent'}
        And I start it
        Then starting is not offered yet
        And nothing was started

    Scenario Outline: a sign-in that ends as the machine cannot say starts where the machine says work can start
        Given the machine says {'an-agent'} is {'NOT_SIGNED_IN'}
        When I start work in this project
        And I call it {'schema-work'}
        And I choose the agent {'An Agent'}
        And I press {'Sign in'}
        And I close the terminal of the sign-in
        And the sign-in ends as {<end>}
        Then starting is offered
        And nothing was started
        Examples:
            | end           |
            | 'CANNOT_SAY'  |
            | 'NO_PROVIDER' |

    Scenario: a sign-in that runs already is waited on, and its own terminal opened, never a second
        Given a sign-in of {'an-agent'} already runs on the machine
        When I start work in this project
        And I choose the agent {'An Agent'}
        Then the sign-in is waited on
        When I press {'Sign in'}
        Then the terminal of {'porelo-login-an-agent'} is open over the form
        And the machine was asked to start {1} sign-ins
        And no sign-in was forced

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

    # Leaving drops only the wait and its connection: the sign-in goes on on the machine.
    Scenario Outline: leaving the form during a sign-in starts nothing and leaves the sign-in running
        Given the machine says {'an-agent'} is {'NOT_SIGNED_IN'}
        When I start work in this project
        And I call it {'schema-work'}
        And I choose the agent {'An Agent'}
        And I press {'Sign in'}
        And I close the terminal of the sign-in
        And I leave the start form by {<how>}
        Then the sign-in is no longer waited on
        When the sign-in ends as {'SIGNED_IN'}
        Then nothing was started
        And the sign-in still runs on the machine
        And it says {'The sign-in to An Agent goes on by itself'}
        And it says {'until it is finished or 30 minutes pass'}
        Examples:
            | how           |
            | 'Escape'      |
            | 'the barrier' |
            | 'Not now'     |

    # A machine no longer watched holds no wait of this window: its connection closes, and the sign-in goes on there.
    Scenario: forgetting the machine of the form drops the wait on its sign-in
        Given the machine says {'an-agent'} is {'NOT_SIGNED_IN'}
        When I watch another machine called {'elsewhere'}
        And I go to the work
        And I select the project {'checkout'}
        And I start work in this project
        And I call it {'schema-work'}
        And I choose the agent {'An Agent'}
        And I press {'Sign in'}
        And I close the terminal of the sign-in
        Then the sign-in is waited on
        When the machine of the form is forgotten
        Then the sign-in is no longer waited on
        And the sign-in still runs on the machine

    # The machine names what attaches to its login: run on that machine, and told the person is elsewhere.
    Scenario: a sign-in on a machine reached over ssh says so and attaches over ssh there
        Given the machine says {'an-agent'} is {'NOT_SIGNED_IN'}
        And the machine is reached over ssh as {'alice@vm'}
        When I go to the work
        And I select the project {'checkout'}
        And I start work in this project
        And I call it {'schema-work'}
        And I choose the agent {'An Agent'}
        And I press {'Sign in'}
        Then the machine was told the person reaches it from another one
        And the terminal of the sign-in runs over ssh on {'alice@vm'}

    # A sign-in the machine already holds is imported first; one of its own is the second decision.
    Scenario: a machine that holds a sign-in already offers its import, and forces nothing by itself
        Given the machine says {'an-agent'} is {'NOT_SIGNED_IN'}
        And the machine refuses the sign-in as {'ALREADY_SIGNED_IN'}
        When I start work in this project
        And I call it {'schema-work'}
        And I choose the agent {'An Agent'}
        And I press {'Sign in'}
        Then the machine was asked to start {1} sign-ins
        And no sign-in was forced
        And starting is not offered yet
        When I press {'Use the sign-in found on the machine'}
        Then starting is offered
        And no sign-in was forced
        And nothing was started

    Scenario: a sign-in anyway is the second press after the machine said it holds one
        Given the machine says {'an-agent'} is {'NOT_SIGNED_IN'}
        And the machine refuses the sign-in as {'ALREADY_SIGNED_IN'}
        When I start work in this project
        And I call it {'schema-work'}
        And I choose the agent {'An Agent'}
        And I press {'Sign in'}
        And I press {'Sign in anyway, beside the sign-in found'}
        Then the last sign-in was forced
        And the terminal of {'porelo-login-an-agent'} is open over the form
        And starting is not offered yet

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

    # Leaving drops only the wait, as leaving the form does: the sign-in goes on on the machine.
    Scenario: leaving the failed start's view drops the wait on its sign-in and leaves the sign-in running
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
        And the sign-in still runs on the machine

    # Left while its start is out: a late answer opens no wait on the machine and no terminal.
    Scenario: leaving the failed start's view while its sign-in starts opens no wait and no terminal
        Given the machine says {'an-agent'} is {'SIGNED_IN'}
        When I start work in this project
        And I call it {'schema-work'}
        And I choose the agent {'An Agent'}
        And I start it
        And the machine says {'an-agent'} is {'NOT_SIGNED_IN'}
        And the machine refuses the start as {'NOT_READY'}
        And the machine holds the sign-in start back
        And I press {'Sign in'}
        And I close what is open
        And the machine answers the sign-in start
        Then no sign-in is waited on
        And no terminal of a sign-in was opened

    Scenario: forgetting the machine while its sign-in starts opens no wait and no terminal
        Given the machine says {'an-agent'} is {'NOT_SIGNED_IN'}
        When I watch another machine called {'elsewhere'}
        And I go to the work
        And I select the project {'checkout'}
        And I start work in this project
        And I call it {'schema-work'}
        And I choose the agent {'An Agent'}
        And the machine holds the sign-in start back
        And I press {'Sign in'}
        And the machine of the form is forgotten
        And the machine answers the sign-in start
        Then no sign-in is waited on
        And no terminal of a sign-in was opened
