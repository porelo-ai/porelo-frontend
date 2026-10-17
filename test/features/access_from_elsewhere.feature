# The Feature line is the report row: one short sentence, 70 characters at most,
# saying what this file tests. It is the group name in every surface CI renders.
Feature: Watching several machines at once, and telling nodes apart

  Background:
    Given a backend with work on it
    And the app is running
    And I go to the work

  Scenario: which machine an action will act on is always visible
    Then the machine shown is {'this machine'}

  Scenario: another machine is watched, and switching moves the whole frame to it
    When I watch another machine called {'elsewhere'}
    And I switch to the machine {'elsewhere'}
    Then the machine shown is {'elsewhere'}
    And the project {'shared'} is listed

  Scenario: the command that forwards a socket is copied rather than retyped
    When I start watching another machine
    And I name the socket {'/tmp/porelo-elsewhere.sock'}
    And I copy the forwarding command
    Then what was copied is {'ssh -L /tmp/porelo-elsewhere.sock:/run/user/<uid>/porelo/porelod.sock user@host -N'}

  Scenario: every machine is watched at once, not only the one being acted on
    When I watch another machine called {'elsewhere'}
    Then every machine is being watched

  Scenario: adding a machine does not move what is being acted on
    When I watch another machine called {'elsewhere'}
    Then the machine shown is {'this machine'}

  Scenario: a lost tunnel reads as a disconnection, never as a machine with nothing on it
    When I select the project {'checkout'}
    And the tunnel drops
    Then the machine is shown as not answering
    And the work {'porelo-checkout-shell'} is listed
    When enough time passes for another try
    Then the machine is shown as answering

  # `Node()` is there for exactly this. A client cannot work it out: a hostname has
  # many spellings, and a socket somebody else forwarded looks nothing like a tunnel raised here.
  # Unsaid, every clearance question on that node arrives twice, and answering one leaves the
  # other on screen until it expires.
  Scenario: one node reached two ways is said, rather than counted as two machines
    Given the machine {'elsewhere'} is the same node
    When I watch another machine called {'elsewhere'}
    And I open the machine list
    Then the machine {'elsewhere'} is shown as the same node as {'this machine'}

  Scenario: two machines that really are two nodes say nothing about each other
    When I watch another machine called {'elsewhere'}
    And I open the machine list
    Then no machine is shown as the same node

  # Absence is not a value. Two daemons too old to answer both say nothing, and saying nothing
  # twice is not saying the same thing.
  Scenario: machines that cannot say which node they are are never merged
    Given no machine can say which node it is
    When I watch another machine called {'elsewhere'}
    And I open the machine list
    Then no machine is shown as the same node

  # A kind is chosen, so the name is the only thing left that can keep the wizard from going on.
  Scenario: a name already watched is marked when the field is left, and nothing is added
    When I start watching another machine
    And I say it is called {'this machine'}
    And I leave the name field
    Then the name is marked as taken by {'this machine'}
    And the machine cannot be watched yet

  # Both names become the same local socket, so they would share one forward.
  Scenario: two names that would share one forward count as the same name
    When I start watching another machine
    And I say it is called {'this-machine'}
    And I leave the name field
    Then the name is marked as taken by {'this machine'}
