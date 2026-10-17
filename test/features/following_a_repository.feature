# The Feature line is the report row: one short sentence, 70 characters at most,
# saying what this file tests. It is the group name in every surface CI renders.
Feature: A project comes to a machine by following its repository

  Background:
    Given a backend with work on it
    And the app is running
    And I go to the work

  # How the commits are checked decides who controls what this machine runs. Nobody's default.
  Scenario: how its commits are checked is chosen, never assumed
    When I follow a repository
    And I name it {'payments'} at {'git@example.org:payments.git'}
    Then following it is not offered yet
    When I choose to check its commits against a key
    Then following it is not offered yet
    When I give the key {'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5'}
    Then following it is offered

  Scenario: a pinned key goes with the follow, and the project is there at once
    When I follow a repository
    And I name it {'payments'} at {'git@example.org:payments.git'}
    And I choose to check its commits against a key
    And I give the key {'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5'}
    And I follow it
    Then the follow was sent with the key {'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5'}
    And it says {'Following, at c0ffee1'}
    When I go to the project it made
    Then the project {'payments'} is the one chosen
    And the title is {'this machine › payments'}

  Scenario: following unverified says what that gives away the moment it is chosen, before following
    When I follow a repository
    And I name it {'payments'} at {'git@example.org:payments.git'}
    And I choose to follow it unverified
    Then it says {'Anybody who can push to the repository decides what this machine runs'}
    When I follow it
    Then the follow was sent unverified

  Scenario: a commit the machine will not take is said, and no project is made of it
    Given the next follow is refused as {'NOT_SIGNED'}
    When I follow a repository
    And I name it {'payments'} at {'git@example.org:payments.git'}
    And I choose to follow it unverified
    And I follow it
    Then it says {'is not signed'}
    And there is no project {'payments'}

  # Its owner rebasing, or somebody re-serving an older signed configuration to put back a rule that
  # was taken away: nothing here can tell which, so it is never taken without a person saying so.
  Scenario: a rewritten history is taken only as a second decision
    Given the next follow finds a rewritten history
    When I follow a repository
    And I name it {'payments'} at {'git@example.org:payments.git'}
    And I choose to follow it unverified
    And I follow it
    Then it says {'Nothing here can tell which'}
    And the follow accepted no rewrite
    When I take the rewritten history
    Then the follow accepted the rewrite

  # The fingerprint is what a refused signature shows, so it is what somebody has in hand to pin.
  Scenario: a key can be pinned by the fingerprint a refusal showed
    When I follow a repository
    And I name it {'payments'} at {'git@example.org:payments.git'}
    And I choose to check its commits against a key
    Then it says {'or its fingerprint'}
    When I give the key {'SHA256:9xQeTbL1'}
    And I follow it
    Then the follow was sent with the key {'SHA256:9xQeTbL1'}

  # A follow that could only fail is not sent: the machine is asked first, without touching the
  # network, and says what is missing and the way out of it.
  Scenario: a repository nothing is set up to reach is not followed, and its connection is offered
    Given the credential check answers {'NO_CREDENTIAL'}
    When I follow a repository
    And I name it {'payments'} at {'git@example.org:payments.git'}
    And I choose to follow it unverified
    And I follow it
    Then it says {'Nothing on this machine is set up to reach this address'}
    And no follow was sent
    And setting up its connection is offered

  Scenario: a credential in a shut vault offers to open it, and follows nothing
    Given the credential check answers {'VAULT_LOCKED'}
    And the machine is reached over ssh as {'alice@vm'}
    When I follow a repository
    And I name it {'payments'} at {'git@example.org:payments.git'}
    And I choose to follow it unverified
    And I follow it
    Then no follow was sent
    When I open the vault from the follow
    Then a terminal runs {'ssh -t alice@vm porelo vault unlock'} on the machine

  # A key is sent from its connection and a file on the machine is replaced there, so neither is
  # a terminal's to store — the way out is the connection itself.
  Scenario: a connection whose value is not there offers the connection, and follows nothing
    Given the credential check answers {'MISSING_VALUE'}
    When I follow a repository
    And I name it {'payments'} at {'git@example.org:payments.git'}
    And I choose to follow it unverified
    And I follow it
    Then it says {'its value is not there'}
    And no follow was sent
    When I show its connection from the follow
    Then the connections of the machine are open
    When I follow a repository
    Then the follow still names {'payments'} at {'git@example.org:payments.git'}

  # The check passes on a key that exists and the forge still turns it away — a key for another
  # repository. What answers that is the connection, so the way there is beside the refusal.
  Scenario: a repository that turned the machine away offers its connections
    Given the credential check answers {'READY'}
    And the next follow is refused as {'UNREACHABLE'}
    When I follow a repository
    And I name it {'payments'} at {'git@example.org:payments.git'}
    And I choose to follow it unverified
    And I follow it
    Then it says {'The repository cannot be reached'}
    When I show the connections after the follow
    Then the connections of the machine are open

  Scenario: a follow turned away for want of a credential says so in words
    Given the next follow is refused as {'NO_CREDENTIAL'}
    When I follow a repository
    And I name it {'payments'} at {'git@example.org:payments.git'}
    And I choose to follow it unverified
    And I follow it
    Then it says {'the machine says nothing it holds reaches the repository'}

  # There and unusable is not the same as missing: storing it again is not the way out.
  Scenario: a credential that is there and cannot be used offers its connection
    Given the credential check answers {'UNUSABLE_VALUE'}
    When I follow a repository
    And I name it {'payments'} at {'git@example.org:payments.git'}
    And I choose to follow it unverified
    And I follow it
    Then it says {'its value cannot be used'}
    And no follow was sent
    When I show its connection from the follow
    Then the connections of the machine are open

  Scenario: a host never met is said as that, never as a missing credential
    Given the next follow is refused as {'UNKNOWN_HOST_KEY'}
    When I follow a repository
    And I name it {'payments'} at {'git@example.org:payments.git'}
    And I choose to follow it unverified
    And I follow it
    Then it says {'this machine has never met that host'}

  # An unknown host key is a question for a person: the keys are shown whole, compared with what the
  # host publishes, and one is trusted by choosing it. Nothing is chosen for them.
  Scenario: a host never met shows its keys, and the one chosen is trusted before following again
    Given the machine has never met the host {'example.org'}
    When I follow a repository
    And I name it {'payments'} at {'git@example.org:payments.git'}
    And I choose to follow it unverified
    And I follow it
    Then it says {'this machine has never met that host'}
    And it says {'SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU'}
    And it says {'not with what this screen says'}
    And trusting is not offered until a key is chosen
    And following it again is not offered
    When I trust the host key {'SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU'} from the follow
    Then the machine trusts {'SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU'} for {'example.org'}, and nothing else
    And the follow was made again, with nothing retyped
    And it says {'Following'}

  # The machine asks the host again and records only the key that was confirmed.
  Scenario: a host that offers other keys by the time one is trusted records nothing
    Given the machine has never met the host {'example.org'}
    When I follow a repository
    And I name it {'payments'} at {'git@example.org:payments.git'}
    And I choose to follow it unverified
    And I follow it
    And {'example.org'} then offers other keys
    And I trust the host key {'SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU'} from the follow
    Then it says {'offers no key with that fingerprint right now'}
    And the follow was not made again

  Scenario: a host key that changed is said as possible interception, and nothing is offered to trust
    Given the machine remembers another key of {'example.org'}
    When I follow a repository
    And I name it {'payments'} at {'git@example.org:payments.git'}
    And I choose to follow it unverified
    And I follow it
    Then it says {'somebody in between'}
    And it says {'SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU'}
    And trusting a host key is not offered
    And following it again is not offered

  Scenario: what was typed is gone once the follow is left
    When I follow a repository
    And I name it {'payments'} at {'git@example.org:payments.git'}
    And I choose {'Leave it'}
    And I follow a repository
    Then the follow still names {''} at {''}

  Scenario: a machine older than the check is still followed, and says itself what is wrong
    Given the machine has no credential check
    When I follow a repository
    And I name it {'payments'} at {'git@example.org:payments.git'}
    And I choose to follow it unverified
    And I follow it
    Then the follow was sent unverified

  Scenario: a local repository needs nothing, and is followed
    Given the credential check answers {'NOT_NEEDED'}
    When I follow a repository
    And I name it {'payments'} at {'/srv/git/payments'}
    And I choose to follow it unverified
    And I follow it
    Then the follow was sent unverified

