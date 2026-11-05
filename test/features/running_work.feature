# The Feature line is the report row: one short sentence, 70 characters at most,
# saying what this file tests. It is the group name in every surface CI renders.
Feature: A tab per running agent, the one place terminals are

    Background:
        Given a backend with work on it
        And the app is running
        And I go to the running work

    # Harm: a tab for work that cannot be attached, or a running agent nobody can reach from here.
    Scenario: every running agent has a tab, and stopped work has none
        Given the work {'porelo-billing-audit'} has stopped
        Then there is a tab for {'porelo-checkout-shell'}
        And there is a tab for {'porelo-billing-shell'}
        And there is no tab for {'porelo-billing-audit'}

    # Harm: typing into the wrong agent because the screen does not say whose it is.
    Scenario: the bar under the tabs names the work, where it runs and its way of working
        When I choose the tab of {'porelo-billing-shell'}
        Then the bar says {'porelo-billing-shell'}
        And the bar says {'billing'}
        And the bar says {'on this machine'}
        And the bar says {'In a terminal'}

    # Harm: the key reaches the far end as input instead of moving, typed into an agent's prompt.
    Scenario: Ctrl and the page keys go to the next agent and back, before a terminal takes them
        When I choose the tab of {'porelo-billing-shell'}
        And I press Ctrl and Page Down
        Then the tab of {'porelo-billing-shell'} is not chosen
        And the session was sent nothing
        When I press Ctrl and Page Up
        Then the tab of {'porelo-billing-shell'} is chosen

    # Harm: two ways in over one terminal, or an agent stopped by moving on.
    Scenario: changing the tab leaves the session, and one stays open
        When I choose the tab of {'porelo-billing-audit'}
        Then {1} sessions are open
        When I press Ctrl and Page Down
        Then {1} sessions are open
        And the session on screen is {'porelo-billing-shell'}
        And the first session was left
        And the work was never stopped

    # Harm: a second input line that does not reach what the agent's own prompt takes.
    Scenario: an agent in a terminal has the terminal and no input line of its own
        When I choose the tab of {'porelo-billing-shell'}
        Then the session is on screen
        And there is no field to type into

    # Measured against the old bar: a full-width dark box that held only this sentence.
    # Harm: attaching starts a new session nobody asked for, or the tab goes with work still running.
    Scenario: a running task whose terminal has ended keeps its tab, says so, and offers a new one
        Given the terminal session of {'porelo-billing-shell'} has ended
        When I choose the tab of {'porelo-billing-shell'}
        Then it says {'No terminal is open in it'}
        And no session is open
        When I open a new terminal from the tab
        Then {1} sessions are open
        And the session on screen is {'porelo-billing-shell'}

    # Measured on a real daemon: a look after the refusal took the session, and with it what the
    # machine had said, and left a sentence that told nothing.
    Scenario: a terminal the machine would not open keeps what was said, whatever a look says after
        When I choose the tab of {'porelo-billing-shell'}
        And the session ends with {69}
        And the terminal session of {'porelo-billing-shell'} has ended
        And {60} seconds pass
        Then it says {'The machine would not open a session here'}
        And it does not say {'No terminal is open in it'}

    # Harm: a row saying nothing of it, or the bar that holds only a sentence.
    Scenario: the row of a running task whose terminal has ended says the same, and draws no console for it
        Given the terminal session of {'porelo-billing-shell'} has ended
        When I go to the list of work
        And I open the tile {'porelo-billing-shell'}
        Then the tile {'porelo-billing-shell'} says {'No terminal is open in it'}
        And the tile of {'porelo-billing-shell'} draws no console
        And the row of {'porelo-billing-shell'} offers {'Open a new terminal'}
        When I open a new terminal from the row of {'porelo-billing-shell'}
        Then the tab of {'porelo-billing-shell'} is chosen
        And {1} sessions are open

    # Harm: a step offered that can only fail, with no way to what the work wrote.
    Scenario: where no terminal can be opened, the tab and the row offer the log
        When I watch another machine called {'elsewhere'}
        And I go to the running work
        And I choose the tab of {'porelo-shared-shell'}
        Then it says {'nowhere to run'}
        And the tab offers to read its log
        When I go to the list of work
        And I open the tile {'porelo-shared-shell'}
        Then the row of {'porelo-shared-shell'} offers {'Read its log'}

    # Harm: a deadline running out behind a terminal, or an answer given where nobody reads it.
    Scenario: work waiting on a person says so under the bar and leads to Needs you
        When work is blocked reaching {'api.example.test:443'}
        And I choose the tab of {'porelo-checkout-shell'}
        Then it says {'Waits on you: asks to reach api.example.test'}
        And it does not say {'Let it through'}
        When I answer in Needs you
        Then the view shown is what needs a person

    # Harm: an unattended agent's tab that shows nothing, or attaches where nobody asked.
    Scenario: an unattended agent shows its log in the console, with a switch to follow it
        Given the work {'porelo-billing-shell'} runs unattended
        When I choose the tab of {'porelo-billing-shell'}
        And the agent of {'porelo-billing-shell'} writes {'reading the contracts'}
        And {1} seconds pass
        Then the console says {'reading the contracts'}
        And the console has a switch to follow it
        And no session is open

    # Harm: the way in by hand taken from unattended work, with no way back to its log.
    Scenario: an unattended agent can still be worked in by hand, and its log followed again
        Given the work {'porelo-billing-shell'} runs unattended
        When I go to the list of work
        And I choose {'Work in it by hand'} from the menu of the tile {'porelo-billing-shell'}
        Then the session on screen is {'porelo-billing-shell'}
        When I follow its log again
        Then no session is open
        And the console has a switch to follow it

    # Harm: a wrong or missing count of what work spent.
    Scenario: an unfolded row says what its work used, as its machine reads it
        Given the work {'porelo-billing-shell'} has used {184000} tokens
        When I go to the list of work
        And I open the tile {'porelo-billing-shell'}
        Then the fact {'tokens'} of {'porelo-billing-shell'} says {'184 k'}

    # Harm: a refusal from an older machine read as zero, or a call for every row whether opened or not.
    Scenario: a machine older than what work used says nothing of it, and is asked only when unfolded
        When I go to the list of work
        Then what {'porelo-billing-shell'} used was not asked for
        When I open the tile {'porelo-billing-shell'}
        Then the fact {'tokens'} of {'porelo-billing-shell'} says {'not said'}
