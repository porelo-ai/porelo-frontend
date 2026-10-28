# The Feature line is the report row: one short sentence, 70 characters at most,
# saying what this file tests. It is the group name in every surface CI renders.
Feature: Starting the agent each repository names, at one click

    Background:
        Given a backend with work on it
        And the app is running
        And I go to the work
        And the project {'checkout'} has the repositories {'checkout, payments-api, ledger, docs'}
        And the repository {'payments-api'} of {'checkout'} names the agent {'an-agent'} going by {'Agent Payments'}
        And the repository {'ledger'} of {'checkout'} names the agent {'other-agent'} going by {'Agent ledger'}

    # The long-running agents of their repositories: attended, no prompt, and one that runs is left alone.
    Scenario: one click starts the agent that is not running, and the running one is not started again
        Given the agent {'an-agent'} works in {'payments-api'} of {'checkout'} as {'payments-api'} and it runs
        When I choose {'Start an agent for each repository…'} from the menu of the project {'checkout'}
        Then it says {'docs names no agent'}
        And it says {'Agent Payments runs already'}
        When I go on
        And I go on
        And I agree to start it
        And the operation finishes
        Then the agents started were {'ledger/other-agent/ledger'}
        And it says {'Agent ledger started'}

    # In the first seconds after a start the machine lists the task before it says its agent: it is that row's.
    Scenario: an agent just started is not offered again while the machine has not said its agent yet
        Given the task {'payments-api'} of {'checkout'} in {'payments-api'} runs before the machine says its agent
        When I choose {'Start an agent for each repository…'} from the menu of the project {'checkout'}
        Then it says {'Agent Payments runs already'}
        And it does not say {'payments-api-2'}

    Scenario: a stopped agent is brought back with its session, not started beside it
        Given the agent {'an-agent'} works in {'payments-api'} of {'checkout'} as {'payments-api'} and it is stopped
        When I choose {'Start an agent for each repository…'} from the menu of the project {'checkout'}
        And I go on
        And I go on
        Then it says {'Agent Payments continues payments-api'}
        When I agree to start it
        And the operation finishes
        And the operation finishes
        Then the agents started were {'payments-api/an-agent/payments-api, ledger/other-agent/ledger'}

    Scenario: a repository left out gets no task
        When I choose {'Start an agent for each repository…'} from the menu of the project {'checkout'}
        And I leave out {'payments-api'}
        And I go on
        And I go on
        Then it says {'payments-api is left out'}
        When I agree to start it
        And the operation finishes
        Then the agents started were {'ledger/other-agent/ledger'}

    # As at a single start: the sign-in comes first, and nothing starts before it - for every agent, not only the first.
    Scenario: each agent with nothing to sign in with holds the wizard until it is signed in
        Given the agent {'an-agent'} has nothing to sign in with
        And the agent {'other-agent'} has nothing to sign in with
        And the agent {'an-agent'} logs in by its own login
        And the agent {'other-agent'} logs in by its own login
        When I choose {'Start an agent for each repository…'} from the menu of the project {'checkout'}
        And I go on
        Then the wizard cannot go on yet
        And nothing was started
        When I sign in to {'an-agent'} from the start of the agents
        And the login stores what {'an-agent'} signed in with
        And the unlock terminal ends and is put away
        Then the wizard cannot go on yet
        When I sign in to {'other-agent'} from the start of the agents
        And the login stores what {'other-agent'} signed in with
        And the unlock terminal ends and is put away
        Then going on is offered

    # An unreadable vault never reads as ready: the machine's words, and asked again once it is dealt with.
    Scenario: a locked vault holds the wizard before the start, and it is asked again by a press
        Given the vault is locked
        When I choose {'Start an agent for each repository…'} from the menu of the project {'checkout'}
        And I go on
        Then the wizard cannot go on yet
        And it says {'the vault is locked, so nothing can say what it holds'}
        When the vault is open again
        And I press {'Ask again'}
        Then going on is offered

    # Asked again for every agent, chosen or not: one taken back in later never keeps an answer from before.
    Scenario: a repository taken back in after the vault opened is asked again with the others
        Given the vault is locked
        When I choose {'Start an agent for each repository…'} from the menu of the project {'checkout'}
        And I leave out {'payments-api'}
        And I go on
        And the vault is open again
        And I press {'Ask again'}
        And I go back
        And I leave out {'payments-api'}
        And I go on
        Then going on is offered

    Scenario: a machine that cannot say whether work can start holds the wizard with its words
        Given the machine fails to say whether work can start, with {'the vault could not be read'}
        When I choose {'Start an agent for each repository…'} from the menu of the project {'checkout'}
        And I go on
        Then the wizard cannot go on yet
        And it says {'the vault could not be read'}
        When the machine answers whether work can start again
        And I press {'Ask again'}
        Then going on is offered

    # The wizard opens at once; nothing on it is judged before the machine has answered.
    Scenario: the wizard opens while the machine is still read, and says so
        Given reading the agents is slow
        When I choose {'Start an agent for each repository…'} from the menu of the project {'checkout'}
        Then it says {'Wait until the machine has said which agents and tasks it has.'}
        When the machine has answered
        Then it does not say {'Wait until the machine has said which agents and tasks it has.'}
        And it says {'Agent ledger'}

    # Agreeing again after one was refused sends only the refused one again, never the one that started.
    Scenario: going back after the starts never starts an agent a second time
        When I choose {'Start an agent for each repository…'} from the menu of the project {'checkout'}
        And I go on
        And I go on
        And I agree to start it
        And the machine refuses the start as {'NOT_READY'}
        And the operation finishes
        And I go back
        And I agree to start it
        And the operation finishes
        Then the agents started were {'payments-api/an-agent/payments-api, ledger/other-agent/ledger, payments-api/an-agent/payments-api'}

    # Leaving is confirmed while a start is out; what is not sent yet is never sent.
    Scenario: leaving while an agent starts sends no further start
        When I choose {'Start an agent for each repository…'} from the menu of the project {'checkout'}
        And I go on
        And I go on
        And I agree to start it
        And I leave the wizard while it works
        And the operation finishes
        Then the agents started were {'payments-api/an-agent/payments-api'}

    # A refusal is that row's answer: it stays on screen, and the next one still starts.
    Scenario: one start refused keeps its refusal while the other starts
        When I choose {'Start an agent for each repository…'} from the menu of the project {'checkout'}
        And I go on
        And I go on
        And I agree to start it
        And the machine refuses the start as {'NOT_READY'}
        And the operation finishes
        Then it says {'This project is not ready to start work.'}
        And it says {'Agent ledger started'}
        And the agents started were {'payments-api/an-agent/payments-api, ledger/other-agent/ledger'}

    # Absent is not "none": an older daemon never says which agent a repository names.
    Scenario: against a machine that does not say which agent a repository names, nothing is offered
        Given the machine does not say which agent its repositories name
        When I open the menu of the project {'checkout'}
        Then the menu offers {'Start an agent for each repository…'} as unavailable because {'does not say which agent'}
