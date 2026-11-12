# The Feature line is the report row: one short sentence, 70 characters at most,
# saying what this file tests. Run by tool/play_story.sh against a local VM, never in the Build.
Feature: A terminal in the window and the live list beside it

    # The window runs in a VM against that VM's own porelo, as the test person. What a step reads it asks
    # of porelo, of the work's own session and of the terminal on the machine, never of the window. A step
    # that fails is noted and the story goes on where the steps after it do not stand on it.
    Scenario: input reaches the work whole, the watch follows it, and Ctrl-C gives the terminal back
        Given the interface is running
        And the test machine has an open vault
        And the test machine has Porelo's stub agent
        And work of the stub agent waits for input on the test machine
        When I work in that work by hand from the interface
        And I type {'Grüße von Zoë, mit Ångström und Leerzeichen'} into the terminal of the work
        And I paste {'erste Zeile|zweite Zeile mit ä|dritte Zeile'} into the terminal of the work
        And I type {'falsch'} and erase it with Ctrl-U before {'richtig'} in the terminal of the work
        Then the work received each line whole and unchanged
        When I run task list --watch in a terminal on the machine beside it
        Then the watch shows the work as porelo lists it
        When the work reaches a host its project did not declare
        Then the watch names the clearance question of the work
        When I end the agent of the work with Ctrl-D in its terminal
        Then the watch shows the work ended as porelo lists it
        When I press Ctrl-C in the watch
        Then the terminal gives an ordinary prompt back
        And the work of the stub agent and its project are removed again
