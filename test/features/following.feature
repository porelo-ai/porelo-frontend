# The Feature line is the report row: one short sentence, 70 characters at most,
# saying what this file tests. It is the group name in every surface CI renders.
Feature: How far following a project's repository has got, and who must act

    Background:
        Given a backend with work on it
        And the app is running
        And I go to the work

    Scenario: a project that is followed says which commit is in force
        Given the project {'checkout'} follows its repository at {'4f2a9c1e0b77'}
        Then the project {'checkout'} says {'Following, at 4f2a9c1'}

    Scenario: a project nobody follows says nothing about following
        Then the project {'checkout'} says nothing about following

    # A good signature by a key this machine was never given is either a key that moved or somebody
    # putting a project file past the machine. It waits for a person, with the key named.
    Scenario: a commit signed by an unknown key is refused, named, and put in front of a person
        Given the newest commit of {'checkout'} is signed by the unknown key {'SHA256:9xQeTbL1'}
        Then the project {'checkout'} says {'signed by a key this machine was never given'}
        And the project {'checkout'} says {'still running 4f2a9c1'}
        When I go to what needs a person
        Then what needs a person names the project {'checkout'}
        And it says {'SHA256:9xQeTbL1'}
        And the count of what needs a person is {'1 need you'}

    # Only the daemon knows what fixes itself: an unreachable repository may answer on the next pass.
    Scenario: a repository that cannot be reached for now is said on the project, and needs nobody
        Given the repository of {'checkout'} cannot be reached for now
        Then the project {'checkout'} says {'The repository cannot be reached'}
        When I go to what needs a person
        Then what needs a person does not name the project {'checkout'}
        And the count of what needs a person is {'nothing needs you'}

    # Nothing is wrong with the network or the URL, so the sentence must not say it is.
    Scenario: a shut store is not an unreachable repository
        Given the repository of {'checkout'} needs a credential from a shut store
        Then the project {'checkout'} says {"This account's store is shut"}
        And the project {'checkout'} does not say {'cannot be reached'}

    # Nothing checks what this machine is handed for it, so it is never shown like a verified one.
    Scenario: a project followed unverified says so, on its header and on its card
        Given the project {'checkout'} is followed unverified
        Then the project {'checkout'} says {'unverified'}
        And the card of {'checkout'} is marked unverified

    Scenario: a project followed with a key is not marked unverified
        Given the project {'checkout'} follows its repository at {'4f2a9c1e0b77'}
        Then the card of {'checkout'} is not marked unverified

    # Walk 10: the card said a rewritten history waits, with no way to take it there.
    Scenario: a rewritten history is taken from what needs a person, after agreeing
        Given the history of {'checkout'} was rewritten
        When I go to what needs a person
        Then what needs a person names the project {'checkout'}
        When I press {'Take the rewritten history'}
        Then it says {'Do this only if you rewrote the history yourself'}
        When I press {'Take it'}
        Then the machine was asked to follow {'checkout'} taking the rewritten history
