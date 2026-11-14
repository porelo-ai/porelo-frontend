# The Feature line is the report row: one short sentence, 70 characters at most,
# saying what this file tests. It is the group name in every surface CI renders.
Feature: A machine reached over ssh opens a shell in the window

    Background:
        Given a backend with work on it
        And the app is running
        And I go to the work

    # Harm: the shell logs in by a key file or a password typed into the window, or reaches another machine.
    Scenario: a machine reached over ssh opens its SSH Console in a terminal in the window
        Given the machine is reached over ssh as {'alice@vm'}
        When I open the SSH Console of {'vm'}
        Then the console runs {'ssh -t alice@vm'}

    # Harm: a console on this computer opens ssh to nowhere.
    Scenario: this computer offers no SSH Console
        Then this computer offers no SSH Console
