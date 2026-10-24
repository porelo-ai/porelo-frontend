# The Feature line is the report row: one short sentence, 70 characters at most,
# saying what this file tests. It is the group name in every surface CI renders.
Feature: A project's conversation, and a person joining it

    Background:
        Given a backend with work on it
        And the app is running
        And I go to the work
        And I select the project {'checkout'}

    Scenario: a project with no conversation is not offered its messages
        When I open the command finder
        Then the command {'Messages — the conversation of this project, and who has joined it'} is unavailable because {'checkout has no conversation'}

    Scenario: where the conversation is, and whether this machine can carry it, is said
        Given the project {'checkout'} has a conversation over {'matrix'} reaching {'127.0.0.1:8008'}, not ready saying {'the homeserver does not answer'}
        When I choose the command {'Messages — the conversation of this project, and who has joined it'}
        Then it says {'Over matrix, reaching 127.0.0.1:8008.'}
        And it says {'This machine cannot carry its messages now: the homeserver does not answer'}
        And it says {'Nobody has joined yet.'}

    # Answered once and kept nowhere: shown whole while the dialog is open, and gone with it.
    Scenario: a person joins, and their login is shown once with the homeserver forwarded here
        Given the machine is reached over ssh as {'alice@vm'}
        And the project {'checkout'} has a conversation over {'matrix'} reaching {'127.0.0.1:8008'}, ready
        And I select the project {'checkout'}
        When I choose the command {'Messages — the conversation of this project, and who has joined it'}
        And I join {'anna'}
        Then the machine was asked to let {'anna'} join {'checkout'}
        And it says {'pw-1-once'}
        And what a walk writes down does not hold {'pw-1-once'}
        And the {'login password'} is blanked in a walk's picture
        And it says {'#porelo-checkout:localhost'}
        And it says {'Matrix ID'}
        And it says {'Homeserver URL'}
        And it says {'anna, as @anna:localhost'}
        And a forward of port {'8008'} is held
        And it says {'port 8008 is forwarded from this computer while this window runs'}
        # Walk 10: nheko lost its server when the dialog closed. Kept while the window runs.
        When I am done with the messages
        Then the forward of port {'8008'} is still held
        When I choose the command {'Messages — the conversation of this project, and who has joined it'}
        Then it says {'A Matrix client here reaches its homeserver at http://127.0.0.1:8008, forwarded while this window runs.'}

    # Walk 10: where the address is said beside the dialog, and a forward that cannot be raised is not quiet.
    Scenario: the homeserver's address is said on the project's page, and a forward that cannot be raised needs you
        Given the machine is reached over ssh as {'alice@vm'}
        And the project {'checkout'} has a conversation over {'matrix'} reaching {'127.0.0.1:8008'}, ready
        And I select the project {'checkout'}
        When I choose the command {'Messages — the conversation of this project, and who has joined it'}
        And I join {'anna'}
        And I am done with the messages
        Then the project header says {'A Matrix client here reaches its homeserver at http://127.0.0.1:8008.'}
        Given the next forward is refused because {'Port 8008 is already in use on this computer.'}
        When the forward of port {'8008'} drops and is tried again
        And I go to what needs a person
        Then it says {'The homeserver of checkout is not reachable from here'}
        And the homeserver notice for {'checkout'} names machine {'vm'}
        And it says {'Port 8008 is already in use on this computer.'}
        And it says {'Try again'}

    Scenario: a person who has joined already is offered a new password, and nothing else
        Given the project {'checkout'} has a conversation over {'matrix'} reaching {'127.0.0.1:8008'}, ready
        And {'anna'} has joined the conversation of {'checkout'}
        When I choose the command {'Messages — the conversation of this project, and who has joined it'}
        And I join {'anna'}
        Then it says {'anna has joined already, as @anna:localhost'}
        When I give a new password
        Then the machine was last asked to let {'anna'} join {'checkout'} with a new password
        And it says {'pw-2-once'}

    # This computer's loopback is the machine's: nothing to forward.
    Scenario: a machine that is this computer forwards nothing for its homeserver
        Given the project {'checkout'} has a conversation over {'matrix'} reaching {'127.0.0.1:8008'}, ready
        When I choose the command {'Messages — the conversation of this project, and who has joined it'}
        And I join {'anna'}
        Then it says {'The homeserver is on this computer, at http://127.0.0.1:8008.'}
        And nothing was forwarded

    Scenario: nobody is joined without a name
        Given the project {'checkout'} has a conversation over {'matrix'} reaching {'127.0.0.1:8008'}, ready
        When I choose the command {'Messages — the conversation of this project, and who has joined it'}
        Then joining is not offered yet
