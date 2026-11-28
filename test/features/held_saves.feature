# The Feature line is the report row: one short sentence, 70 characters at most,
# saying what this file tests. It is the group name in every surface CI renders.
Feature: Saves the planner holds wait in Needs you until resent or dropped

    Background:
        Given a backend with planning
        And the app is running
        And I go to what needs a person

    # Harm: a save the planner could not write waits unseen, or stays counted once it was written.
    Scenario: A save made on the board is held with Resend and Drop, and Resend clears it
        When the planner holds a save of {'cart-move'} made on the board
        Then Needs you holds the held saves of {'checkout'}
        And the held save of {'cart-move'} offers {'Resend and Drop'}
        # The work on the machine already waits on one question; the held saves are the second row.
        And Needs you counts {2}
        When I resend the held save of {'cart-move'}
        Then Needs you holds no held saves of {'checkout'}
        And Needs you counts {1}
        And the planner was asked to {'resend'} the held save of {'cart-move'}

    # Harm: a person decides on a held save without seeing what it changes, what the forge answered or how often it was
    # tried, or cannot hand the forge's request id on whole.
    Scenario: A held save opens to its change, the forge's answer and its tries, and its request id copies whole
        When the planner holds a save of {'cart-move'} made on the board
        And I open the held save of {'cart-move'}
        Then the held save of {'cart-move'} shows its change, the forges answer and its tries
        When I copy the request id of the held save of {'cart-move'}
        Then the clipboard holds the request id alone

    # Harm: the issue a held save changes is named in its card but cannot be opened, so the person looks it up by hand.
    Scenario: The issue of a held save opens its page in the browser
        Given the board of {'checkout'} gives {'cart-move'} the page {'https://example.org/stories/cart-move'}
        When the planner holds a save of {'cart-move'} made on the board
        And I open the issue of the held save of {'cart-move'}
        Then the browser was given {'https://example.org/stories/cart-move'}

    # Harm: a halted run's save is offered again from here, where only its run's Stop or Start decides it.
    Scenario: A halted run's held save can only be dropped
        When the planner holds a save of {'cart-move'} made by a halted run
        Then Needs you holds the held saves of {'checkout'}
        And the held save of {'cart-move'} offers {'Drop only'}

    # Harm: a save the person gave up stays in Needs you, or is written after all.
    Scenario: Drop removes a held save and writes nothing
        When the planner holds a save of {'cart-move'} made by a halted run
        And I drop the held save of {'cart-move'}
        Then Needs you holds no held saves of {'checkout'}
        And the planner was asked to {'drop'} the held save of {'cart-move'}

    # Harm: a resend the planner refused reads as written, or its reason is lost. The words are the planning screen's
    # own for SaveNotHeld, the same whatever text the planner sent with it.
    Scenario: A refused resend says the planner's reason and keeps the save
        Given the planner refuses to resend a save as no longer held
        When the planner holds a save of {'cart-move'} made on the board
        And I resend the held save of {'cart-move'}
        Then the held saves of {'checkout'} say {'The save is not held: it runs, or was sent again.'}
        And Needs you holds the held saves of {'checkout'}
