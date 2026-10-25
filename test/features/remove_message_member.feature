Feature: Removing a person from a project room

    Background:
        Given a backend with work on it
        And the app is running
        And I go to the work
        And I select the project {'checkout'}
        And the project {'checkout'} has a conversation over {'matrix'} reaching {'127.0.0.1:8008'}, ready
        And {'anna'} has joined the conversation of {'checkout'}
        And {'bea'} has joined the conversation of {'checkout'}
        When I choose the command {'Messages and the project’s room'}

    # Harm: the requested account stays in the room, or another person is removed instead.
    Scenario: confirmation removes only the selected person
        When I ask to remove room member {'anna'}
        Then the room lists {'anna,bea'}
        When I press {'Remove'}
        Then the room lists {'bea'}

    # Harm: removing an account without a confirmed decision revokes access unexpectedly.
    Scenario: cancelling keeps the account in the room
        When I ask to remove room member {'anna'}
        And I press {'Cancel'}
        Then the room lists {'anna,bea'}

    # Harm: a remembered removed account prevents joining again across reopening.
    Scenario: removing the current account offers Join again
        When I join {'anna'}
        And I give a new password
        And I ask to remove room member {'anna'}
        And I press {'Remove'}
        Then the room lists {'bea'}
        And Join is offered again
        When I am done with the messages
        And I choose the command {'Messages and the project’s room'}
        Then Join is offered again

    # Harm: a failed removal is presented as success.
    Scenario: a member removed elsewhere is shown as a refusal
        Given room member {'anna'} has left {'checkout'} at the machine
        When I ask to remove room member {'anna'}
        And I press {'Remove'}
        Then removal is refused for absent member {'anna'}
        And the room still displays member {'anna'}

    # Harm: a retained account is presented as deleted.
    Scenario: a kept account shows the transport explanation
        Given the transport keeps account {'@anna:localhost'} because {'It belongs to another room too; its account remains.'}
        When I ask to remove room member {'anna'}
        And I press {'Remove'}
        Then the room lists {'bea'}
        And the kept account explanation is shown

    # Harm: a transport refusal is mistaken for a successful removal.
    Scenario: a transport refusal preserves the member
        Given removing a room member is refused with {'The homeserver refused this operation.'}
        When I ask to remove room member {'anna'}
        And I press {'Remove'}
        Then removal is refused with {'The homeserver refused this operation.'}
        And the room lists {'anna,bea'}

    # Harm: a missing method leaves an action appearing to succeed or disables other features.
    Scenario: an older daemon disables only Remove after answering
        Given the machine cannot remove room members yet
        When I ask to remove room member {'anna'}
        And I press {'Remove'}
        Then room member removal is unavailable
        And the room lists {'anna,bea'}
        When I join {'cara'}
        Then the room lists {'anna,bea,cara'}
