Feature: Developer access changes require review

    Background:
        Given the developer settings list an existing developer

    # Harm: an accidental dismissal must not revoke a person's host or forge access.
    Scenario: canceling a developer removal keeps access
        When I cancel the developer removal
        Then no developer access change has been requested

    # Harm: confirmation must act on the selected account only.
    Scenario: confirming a developer removal acts on that account
        When I confirm the developer removal
        Then removal was requested for the selected developer

    # Harm: a pasted private key must not enter a form or signed file.
    Scenario: private key input never leaves the public key step
        When I paste a private key at the developer laptop step
        Then the developer public key field contains no private key
        And no developer access change has been requested

    # Harm: an unreviewed laptop must not grant host or forge access.
    Scenario: public laptop keys are reviewed before publication
        When I review a new developer with two laptops
        Then no developer access change has been requested
        When I publish the reviewed developer
        Then the requested developer has both public laptops
