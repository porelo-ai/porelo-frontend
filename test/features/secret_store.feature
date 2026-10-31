# The Feature line is the report row: one short sentence, 70 characters at most,
# saying what this file tests. It is the group name in every surface CI renders.
Feature: Seeing and shutting the secret store, without showing a value

    Background:
        Given a backend with work on it
        And the app is running
        And I go to the work

    Scenario: what the store holds is visible without doing anything to it
        When I show the vault
        Then it lists the credential {'a-provider'}
        And it says {'open — its contents can be read'}
        And nothing was done to the store

    Scenario: a value is never shown, only that something is there
        When I show the vault
        Then it says {'api-key · 108 characters'}

    Scenario: shutting it says what locking could not reach
        Given two running tasks still hold what they read
        When I show the vault
        And I shut the store
        Then it says {'The vault is shut.'}
        And it says {'2 running tasks still hold what they read at start'}

    Scenario: a store that was already shut says so rather than claiming it did something
        Given the store was already shut
        When I show the vault
        And I shut the store
        Then it says {'The vault was already shut.'}

    Scenario: a shut store is not an empty one
        Given the store is shut
        When I show the vault
        Then it says {'That is not the same as it holding nothing'}
        And it does not list any credential

    Scenario: an open store holding nothing says that, as a state
        Given the store is open and holds nothing
        When I show the vault
        Then it says {'It is open and holds nothing. That is a state, not a failure.'}

    # One line rather than a paragraph per thing: where each happens is all somebody needs.
    Scenario: what happens at the machine instead is said in one line
        When I show the vault
        And I read to the bottom of the store
        Then it says {'`porelo vault unlock` opens it without a device'}
        And it says {'`porelo vault passphrase` changes its passphrase'}

    Scenario: a slow answer never lands on top of a newer one
        Given reading the store is slow
        When I ask about the store twice
        Then the newer answer is the one on screen

    # A device can only be enrolled into an open store, so the first opening is always by the
    # passphrase — typed into a terminal on the machine, never into this program.
    Scenario: a shut store is opened by its passphrase in a terminal on the machine, then asked again
        Given the store is shut
        And the machine is reached over ssh as {'alice@vm'}
        When I show the vault
        And I open it here with its passphrase
        Then a terminal runs {'ssh -t alice@vm porelo vault unlock'} on the machine
        When the unlock terminal ends and is put away
        Then the machine is asked again whether the store is open

    Scenario: a shut store on a device that is not enrolled is opened from the lock by its passphrase
        Given the store is shut
        And the machine is reached over ssh as {'alice@vm'}
        When I open the store with its passphrase from the lock
        Then a terminal runs {'ssh -t alice@vm porelo vault unlock'} on the machine

    # A socket somebody else forwarded has no host behind it; a porelo run here would open another vault.
    Scenario: a machine whose socket somebody else forwards is not offered a terminal to open it
        Given the store is shut
        And the machine is a socket somebody else forwards
        When I open the command finder
        Then the command {'Open the vault with its passphrase, in a terminal'} is unavailable because {'forwarded by somebody else'}

    Scenario: this machine's own daemon is opened by its own porelo, here
        Given the store is shut
        When I show the vault
        And I open it here with its passphrase
        Then a terminal runs {'porelo vault unlock'} on the machine

    # A fresh machine has no store, and enrolling and opening both start from one being there.
    Scenario: a machine with no store is offered to make one from the lock, in a terminal there
        Given the machine is reached over ssh as {'alice@vm'}
        And the machine has no store yet
        When I open the store with its passphrase from the lock
        Then a terminal runs {'ssh -t alice@vm porelo vault init'} on the machine

    # The machine's own page offers the first step among its commands.
    Scenario: a machine with no store makes it from the machine's menu, in a terminal there
        Given the machine is reached over ssh as {'alice@vm'}
        And the machine has no store yet
        When I choose the command {'Make the vault, in a terminal'}
        Then a terminal runs {'ssh -t alice@vm porelo vault init'} on the machine

    Scenario: a machine with a store offers no second one
        When I open the command finder
        Then the command {'Make the vault, in a terminal'} is offered as unavailable

    # A store that is not there answers readable, because there is nothing to open. That is not an
    # open store, and saying so would send somebody looking for a store that does not exist.
    Scenario: a machine with no store does not say one is open and empty
        Given the machine has no store yet
        When I show the vault
        Then it says {'There is no vault yet'}
        And it does not say {'It is open and holds nothing'}
        And the lock does not show an open store

    Scenario: the store's own view makes one where there is none, and asks the machine afterwards
        Given the machine has no store yet
        When I show the vault
        And I make it here with a passphrase
        Then a terminal runs {'porelo vault init'} on the machine
        When the unlock terminal ends and is put away
        Then the machine is asked again whether the store is open


    # Settings go with a secret and are not one: shown whole, as the configuration they are.
    Scenario: an entry's settings are shown whole beside it
        Given the store holds {'f56-api'} with the setting {'token_url'} as {'https://auth.example.com/token'}
        When I show the vault
        Then it says {'token_url: https://auth.example.com/token'}
