# The Feature line is the report row: one short sentence, 70 characters at most,
# saying what this file tests. It is the group name in every surface CI renders.
Feature: Which providers a machine is authenticated against

  Background:
    Given a backend with work on it
    And the app is running
    And I go to the work

  # Named as what they are rather than as bare identifiers — and the identifier is kept beside
  # the name, because it is what an agent and `vault put` both take.
  Scenario: what a machine can authenticate against is listed with what each one is
    When I show what this machine can authenticate against
    Then it says {'A Provider'}
    And it says {'Another Provider'}
    When I open the provider {'A Provider'}
    Then it says {'api.example.test'}

  Scenario: which are authenticated and which are not is stated
    When I show what this machine can authenticate against
    Then it says {'a-provider · authenticated'}
    And it says {'other-provider · not authenticated'}

  # The key is usually the provider's own name — but a vault written before credentials were keyed
  # by provider answers under the AGENT's name, and that key stays in use. Intersecting two lists
  # here would report a credential missing from precisely the vault that has one.
  Scenario: where a credential belongs is taken from the machine, never worked out here
    When I show what this machine can authenticate against
    And I open the provider {'Another Provider'}
    Then it says {'an-agent'}
    And the command to store one is {'porelo vault put an-agent --type oauth'}

  Scenario: nothing here asks for a secret, and it says where one is typed instead
    When I show what this machine can authenticate against
    Then it says {'Nothing here asks for a secret'}
    And it says {'in the terminal half of the connection this window already uses'}

  # A locked store and an unauthenticated provider are different sentences, and only one of them
  # is somebody's problem. The same trap the credential list had.
  Scenario: a shut store says it cannot tell, rather than showing everything as unauthenticated
    Given the store cannot be read
    When I show what this machine can authenticate against
    Then it says {'cannot say while the vault is shut'}
    And it says {'That is not the same as none of them being'}

  # The daemon reads the agent's own config file on its own disk. Only a name crosses.
  Scenario: what an agent already holds there is imported without a secret crossing
    When I show what this machine can authenticate against
    And I open the provider {'A Provider'}
    And I import what the agent already has
    Then it says {'Stored as an-agent: 51 characters'}
    And no secret crossed the socket

  # Ordinary, not a fault: the agent is installed and nobody has logged in with it there yet.
  Scenario: nothing to import is a sentence with a next step, never a failure
    Given importing will find nothing
    When I show what this machine can authenticate against
    And I open the provider {'A Provider'}
    And I import what the agent already has
    Then it says {'nobody has logged in with it on that machine yet'}
    And it says {'Logging in there is the next step'}

  Scenario: a shut store is not drawn as a missing credential
    Given importing will find the store shut
    When I show what this machine can authenticate against
    And I open the provider {'A Provider'}
    And I import what the agent already has
    Then it says {'The vault is shut, so nothing here can say whether it holds one'}

  # `Login` is held open rather than built: getting a credential is the agent's own login on the
  # machine, and how that works is per-agent knowledge that would go stale here silently. What the
  # screen owes is what differs between the ways in, and where the choosing happens.
  Scenario: where a provider has more than one way in, what differs is said
    When I show what this machine can authenticate against
    And I open the provider {'Another Provider'}
    Then it says {'A key and a subscription token are stored differently'}
    And it says {'the agent’s own login, on the machine'}
