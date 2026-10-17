# The Feature line is the report row: one short sentence, 70 characters at most,
# saying what this file tests. It is the group name in every surface CI renders.
Feature: Opening the store with an enrolled device, never with a passphrase

    # Against the keyslots' proposal, which is not built yet: the fake answers the way the proposal
    # says a node does — a share it has seen opens its slot, nothing else does.
    Background:
        Given a backend with work on it
        And the app is running
        And I go to the work

    Scenario: a device that is not enrolled is offered enrolling in the machine's menu, not in the title
        Then enrolling is offered in the machine's menu
        And the title bar carries no enrolling
        And the store's lock says {'The vault is open. Shut it.'}

    Scenario: enrolling keeps a key here and the machine lists this device
        When I enroll this device as {'laptop'}
        Then it says {'This device can open the vault now, as "laptop".'}
        When I close the answer
        And I show the vault
        Then it says {'laptop — this device'}
        And this device keeps the key the machine was given
        And enrolling is unavailable in the machine's menu because {'enrolled already'}

    Scenario: before a device is enrolled, it says what its key is kept in
        When I begin enrolling this device
        Then it says {'anything running as this user can read it'}

    Scenario: the key itself is never on screen
        When I enroll this device as {'laptop'}
        And I close the answer
        And I show the vault
        Then the key this device keeps is nowhere on screen

    # On a machine whose socket somebody else forwards: nothing here can reach its porelo, so there is
    # no terminal to open it in either, and the lock can only say where it is opened.
    # A vault made again keeps the node and loses its devices: a key kept here for the old one is not
    # an enrollment, and the lock must not send it.
    Scenario: a key kept for a slot the machine no longer has is not taken for an enrollment
        Given the store is shut
        And this device keeps a key the machine no longer has a slot for
        Then the store's lock says {'Shut. Open it with its passphrase, in a terminal on the machine'}
        And enrolling is unavailable in the machine's menu because {'the vault is shut'}

    Scenario: a shut store and a device that is not enrolled say where it is opened instead
        Given the store is shut
        And the machine is a socket somebody else forwards
        Then the store's lock says {'The vault is shut, and this device is not enrolled. Unlock it at the machine with `porelo vault unlock`, then enroll this device.'}
        And the store's lock does nothing
        And enrolling is unavailable in the machine's menu because {'the vault is shut'}

    # No default length: a bound that crept in would decide how often somebody is asked, and so would
    # its absence. Opening is refused until a length is chosen.
    Scenario: opening it asks how long, and chooses nothing for the person
        When I enroll this device as {'laptop'}
        And I close the answer
        And I shut the store
        And I close the answer
        And I begin opening the store with this device
        Then it cannot be opened until a length is chosen

    Scenario: opening it for an hour asks the machine for sixty minutes, and it is open
        When I enroll this device as {'laptop'}
        And I close the answer
        And I shut the store
        And I close the answer
        And I open the store with this device {'for an hour'}
        Then the machine was asked to open it for {60} minutes
        And it says {'The vault is open until'}
        When I close the answer
        Then the store's lock says {'The vault is open. Shut it.'}

    Scenario: opening it until it is shut asks for no bound
        When I enroll this device as {'laptop'}
        And I close the answer
        And I shut the store
        And I close the answer
        And I open the store with this device {'until it is shut'}
        Then the machine was asked to open it without a bound

    Scenario: revoking another device keeps this one
        Given another device {'old phone'} can open the store
        When I enroll this device as {'laptop'}
        And I close the answer
        And I show the vault
        And I revoke {'old phone'}
        Then it says {'"old phone" can no longer open the vault.'}
        And this device keeps the key the machine was given

    Scenario: revoking this device forgets its key here, and enrolling is offered again
        When I enroll this device as {'laptop'}
        And I close the answer
        And I show the vault
        And I revoke {'laptop'}
        Then this device keeps no key for the machine
        And enrolling is offered in the machine's menu

    # The way in when every device is gone. Revoking it from a window that may have lost its devices
    # is not offered; it is changed at the machine.
    Scenario: the recovery passphrase is listed and cannot be revoked from here
        When I show the vault
        Then it says {'The passphrase, used at the machine.'}
        And the recovery passphrase cannot be revoked from here

    Scenario: a machine whose Porelo predates devices has the lock, and says why not enrolling
        Given the machine cannot enroll devices yet
        Then the store's lock says {'The vault is open. Shut it.'}
        And enrolling is unavailable in the machine's menu because {'cannot enroll devices yet'}
        When I show the vault
        Then it says {'that arrives with a later Porelo'}

    # Whatever the title shows, the machine's menu has all three.
    Scenario: the machine's menu shuts the store too
        Given the machine is a socket somebody else forwards
        When I shut the store from the machine's menu
        Then it says {'The vault is shut.'}
        When I close the answer
        Then the store's lock says {'The vault is shut, and this device is not enrolled. Unlock it at the machine with `porelo vault unlock`, then enroll this device.'}

    Scenario: a key the machine already took is said as enrolled already, and makes no second slot
        Given the key of this device reached the machine as {'desk'} and its answer did not
        When I enroll this device as {'laptop'}
        Then it says {'This device was enrolled already, as "desk".'}
        And the machine holds {1} devices

    Scenario: a keystore that refuses is said as that, and nothing is sent
        Given the keystore of this device refuses with {'no Secret Service is running'}
        When I enroll this device as {'laptop'}
        Then it says {'keystore refused (no Secret Service is running)'}
        And no key was sent to the machine

    Scenario: a machine that refuses the enrollment leaves no key here
        Given the machine refuses enrolling with {'VAULT_WITHOUT_KEYSLOTS'}
        When I enroll this device as {'laptop'}
        Then it says {'This machine has no vault that devices can open.'}
        And this device keeps no key for the machine

    Scenario: a connection lost while enrolling keeps the key, for the same key to be sent again
        Given the connection goes while enrolling
        When I enroll this device as {'laptop'}
        Then it says {'Lost contact with the machine'}
        And this device keeps a key for the machine

    Scenario: a device whose slot was taken away elsewhere is told so when it opens the store
        When I enroll this device as {'laptop'}
        And I close the answer
        And I shut the store
        And I close the answer
        And the machine takes away the slot of {'laptop'}
        And I open the store with this device {'for an hour'}
        Then it says {'it was revoked, or never enrolled on this machine'}

    Scenario: the list says of each device when it was enrolled and when it last opened the store
        Given another device {'old phone'} can open the store
        When I enroll this device as {'laptop'}
        And I close the answer
        And I show the vault
        Then it says {'Enrolled 2026-09-10, last used 2026-09-17.'}
        And it says {'Enrolled 2026-09-18, not used yet.'}

    Scenario: revoking this device says before it is done that this device will not open the store
        When I enroll this device as {'laptop'}
        And I close the answer
        And I show the vault
        And I begin revoking {'laptop'}
        Then it says {'This device will no longer open the vault, and forgets its key.'}

    Scenario: revoking another device names it before it is done
        Given another device {'old phone'} can open the store
        When I show the vault
        And I begin revoking {'old phone'}
        Then it says {'"old phone" will no longer open the vault.'}

    Scenario: a key kept in a keyring that opens at login is said to be readable by this user
        Given another device {'desk'} keeps its key {'USER_SCOPED'}
        When I show the vault
        Then it says {'Kept in a keyring that opens at login: anything running as this user can read it.'}

    Scenario: a key only its application can read is said as that
        Given another device {'phone'} keeps its key {'APPLICATION_SCOPED'}
        When I show the vault
        Then it says {'Kept where only this application can read it.'}

    Scenario: a key released by a security key is said as that
        Given another device {'token'} keeps its key {'FIDO2'}
        When I show the vault
        Then it says {'Released only with a touch on a security key.'}

    Scenario: a key released by a TPM is said as that
        Given another device {'server'} keeps its key {'TPM2'}
        When I show the vault
        Then it says {'Released only with a PIN, by this machine'}

    Scenario: a way of keeping a key this build does not know claims nothing
        Given another device {'future'} keeps its key {'ENCLAVE'}
        When I show the vault
        Then it says {'Kept in a way this build cannot describe, so nothing is claimed for it.'}

    Scenario: the answer to enrolling says what the machine recorded
        When I enroll this device as {'laptop'}
        Then it says {'Recorded as slot-1. Kept in a keyring that opens at login'}

    Scenario: the answer to revoking says what can still open the store
        Given another device {'old phone'} can open the store
        When I enroll this device as {'laptop'}
        And I close the answer
        And I show the vault
        And I revoke {'old phone'}
        Then it says {'Still able to open it: "laptop" and the passphrase, at the machine.'}
