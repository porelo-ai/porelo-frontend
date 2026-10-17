# The Feature line is the report row: one short sentence, 70 characters at most,
# saying what this file tests. It is the group name in every surface CI renders.
Feature: Listing the agents a machine has, and what each one may reach

  Background:
    Given a backend with work on it
    And the app is running
    And I go to the work

  Scenario: every installed agent is listed with its version and where it was found
    When I show the agents installed here
    Then it lists the agent {'An Agent'}
    And it says {'2.4.0'}
    When I open the agent {'An Agent'}
    Then it says {'/usr/share/porelo/agents/an-agent.yml'}

  Scenario: an agent that reports no version says so rather than showing a blank
    When I show the agents installed here
    Then it says {'version not reported'}

  Scenario: what an agent needs to reach is shown with it
    When I show the agents installed here
    And I open the agent {'An Agent'}
    Then it shows the host {'api.anthropic.com'}

  Scenario: an agent that could not describe itself is listed, not left out
    Given one agent on the machine cannot be read
    When I show the agents installed here
    Then it lists the unusable agent {'broken-agent'}

  Scenario: a machine with nothing installed says so, as a state rather than a failure
    Given the machine has no agents
    When I show the agents installed here
    Then it says {'That is a state, not a failure'}

  Scenario: what an agent is deliberately refused is shown beside what it may reach
    When I show the agents installed here
    And I open the agent {'An Agent'}
    Then it shows the refused host {'telemetry.example.test'}
    And it says {'deliberately not given'}

  Scenario: the pinned build and its digest are shown
    When I show the agents installed here
    And I open the agent {'An Agent'}
    Then it says {'2.4.0'}
    And it shows the digest {'3b1f8e2a9c4d5067a1b2c3d4e5f60718293a4b5c6d7e8f90a1b2c3d4e5f60718'}

  Scenario: a fetch nobody can check says why, rather than showing a blank
    When I show the agents installed here
    And I open the agent {'Another Agent'}
    Then it says {'Not checked, on purpose: upstream publishes no digest'}

  Scenario: an agent that fetches nothing says so, rather than showing an empty list
    Given the agent {'An Agent'} fetches nothing
    When I show the agents installed here
    And I open the agent {'An Agent'}
    Then it says {'It writes its tool into the image'}

  Scenario: a copy that is installed and never used names the one that runs instead
    Given one agent is shadowed by another copy
    When I show the agents installed here
    Then it lists the unused copy {'/usr/libexec/porelo/agents/an-agent'}
    And it says {'runs instead'}

  # The answer to "did a person or an agent write this commit?", which had nowhere to be looked up
  # before `commitsAs` was on the wire. It is also what a pre-push guard on somebody's own
  # checkout matches on, so what is shown here and what that guard uses have to be the same thing.
  Scenario: an agent says who its commits are attributed to
    When I show the agents installed here
    And I open the agent {'An Agent'}
    Then it says {'An Agent <an-agent@porelo.invalid>'}

  Scenario: an agent installed before that was reported says so rather than showing a blank
    When I show the agents installed here
    And I open the agent {'Another Agent'}
    Then it says {'not recorded — installed before this was reported'}
