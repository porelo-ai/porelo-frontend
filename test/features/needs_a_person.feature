# The Feature line is the report row: one short sentence, 70 characters at most,
# saying what this file tests. It is the group name in every surface CI renders.
Feature: What needs a person on every machine, without going anywhere

  Background:
    Given a backend with work on it
    And the app is running
    And I go to what needs a person

  Scenario: what needs a person is one step from the work the window opens on
    Then the view shown is what needs a person

  # Running and stopped work is in its machine's area. Only the gate's work needs somebody here.
  Scenario: work that needs nobody is not on what needs a person
    Then the first tile is {'porelo-checkout-migrate'}
    And no tile is shown for {'porelo-billing-shell'}
    And no tile is shown for {'porelo-checkout-shell'}

  Scenario: a question waiting for an answer is above work that is merely running
    When other work is blocked reaching {'files.example.test:22'}
    Then the first tile is {'porelo-billing-shell'}

  # Time remaining needs a deadline, and the machine does not send one yet.
  Scenario: a question says how long it has been blocked, not a deadline nobody sent
    When work is blocked reaching {'api.example.test:443'}
    Then the tile {'porelo-checkout-shell'} says {'blocked for'}
    And the tile {'porelo-checkout-shell'} says {'does not say when'}

  Scenario: a question is answered from its tile, without leaving the view
    When work is blocked reaching {'api.example.test:443'}
    And I let it through from its tile
    Then the answer sent was {'allow'}
    And the view shown is what needs a person

  # The answer's confirmation would otherwise go with the click that gave it.
  Scenario: a question let through stays with its answer until it is put away
    When work is blocked reaching {'api.example.test:443'}
    And I let it through from its tile
    And the answer comes back
    Then the tile {'porelo-checkout-shell'} says {'is now reachable'}
    When I put away what the tile {'porelo-checkout-shell'} says
    Then no tile is shown for {'porelo-checkout-shell'}

  # A question that ran out while nobody looked would otherwise leave without a trace.
  Scenario: a question that ran out stays, saying so, until it is put away
    When work is blocked reaching {'api.example.test:443'}
    And the question runs out
    Then the tile {'porelo-checkout-shell'} says {'ran out'}
    When I put away what the tile {'porelo-checkout-shell'} says
    Then no tile is shown for {'porelo-checkout-shell'}

  Scenario: a question on another machine is in the same list, with its machine on it
    When I watch another machine called {'elsewhere'}
    And work on {'elsewhere'} is blocked reaching {'api.example.test:443'}
    Then the tile {'porelo-shared-shell'} says {'elsewhere'}

  # A machine is not work, so it is no tile; its silence may hide a question, so it is no absence.
  Scenario: a machine that cannot be reached says so above the tiles, not as one
    When the tunnel drops
    Then a machine notice says {'cannot be reached'}
    And no tile says {'cannot be reached'}
    When enough time passes for another try
    Then no machine notice says {'cannot be reached'}

  # Most people run no Porelo on the computer the interface runs on: that computer is not silent.
  Scenario: this computer, with no Porelo installed, is not said to be unreachable
    Given Porelo is not installed on this computer
    When the tunnel drops
    Then no machine notice says {'cannot be reached'}
    When enough time passes for another try
    Then no machine notice says {'cannot be reached'}

  Scenario: the keyboard works the moment the window opens
    When I open the command finder
    Then the command finder is open

  # The contract's own warning: the same node listed twice asks every question twice.
  Scenario: one node reached two ways asks each question once
    Given the machine {'elsewhere'} is the same node
    When I watch another machine called {'elsewhere'}
    And the same question arrives through both
    Then {1} tile asks to reach {'api.example.test'}

  # Nothing is narrowed here, so the run to continue finds its project through the work itself.
  Scenario: a finished run is continued from its tile, without going to its project
    When I choose {'Continue this work with a new prompt'} from the menu of the tile {'porelo-checkout-migrate'}
    Then what to ask it says {'Fix the rounding in Money.pennies'}

  Scenario: work waiting at the gate is reviewed from its tile, over the view
    When I review the work {'porelo-checkout-migrate'} from its tile
    And I open the waiting push
    Then the review shows the file {'lib/money.dart'}

  Scenario: a question with a deadline says how long is left
    When work is blocked reaching {'api.example.test:443'} with {3} minutes left
    Then the tile {'porelo-checkout-shell'} says {'3 minutes left'}

  Scenario: a question that never runs out says so, rather than counting down
    When work is blocked reaching {'api.example.test:443'} with no deadline
    Then the tile {'porelo-checkout-shell'} says {'does not run out'}

  Scenario: a question past its deadline says its time is up, not how long is left
    When work is blocked reaching {'api.example.test:443'} past its deadline
    Then the tile {'porelo-checkout-shell'} says {'out of time'}
    And the tile {'porelo-checkout-shell'} does not say {'left'}

  # Alphabetical order would put billing first; only the deadline puts checkout there.
  Scenario: the question nearest its deadline comes first
    When work is blocked reaching {'api.example.test:443'} with {2} minutes left
    And other work is blocked reaching {'files.example.test:22'} with {10} minutes left
    Then the first tile is {'porelo-checkout-shell'}

  # A local command reaches only this machine's daemon, and the task is on the other one.
  Scenario: work reached through a forwarded socket offers no session, and says why
    When I watch another machine called {'elsewhere'}
    And work on {'elsewhere'} is blocked reaching {'api.example.test:443'}
    And I open the menu of the tile {'porelo-shared-shell'}
    Then the menu offers {'Work in it by hand'} as unavailable because {'forwarded'}

  # The menu's action goes to the tile's machine, not to the one the rail is acting on.
  Scenario: stopping from another machine's tile stops it there
    When I watch another machine called {'elsewhere'}
    And work on {'elsewhere'} is blocked reaching {'api.example.test:443'}
    And I choose {'Stop it, keeping its workspace'} from the menu of the tile {'porelo-shared-shell'}
    Then {'porelo-shared-shell'} was stopped on the machine {'elsewhere'}
    And nothing was stopped on this machine

  Scenario: every tile is headed by the machine its work is on
    When I watch another machine called {'elsewhere'}
    And work is blocked reaching {'api.example.test:443'}
    And work on {'elsewhere'} is blocked reaching {'files.example.test:22'}
    Then the tile {'porelo-shared-shell'} is headed {'elsewhere'}
    And the tile {'porelo-checkout-shell'} is headed {'this machine'}

  # Seen means seen for now: a machine that answers and later falls silent again says so again.
  Scenario: a silent machine can be marked as seen, until it has answered again
    When the tunnel drops
    And I mark the notice about {'this machine'} as seen
    Then no machine notice says {'cannot be reached'}
    And nothing needs me
    When enough time passes for another try
    And the tunnel drops
    Then a machine notice says {'cannot be reached'}
    When enough time passes for another try
    Then no machine notice says {'cannot be reached'}

  # A question the machine dropped because it was read too slowly is not asked again.
  Scenario: questions a machine dropped unseen are said, until marked seen
    When the machine dropped {2} questions unseen
    Then it says {'dropped 2 questions about a blocked connection before it was seen'}
    And it says {'A dropped question is not asked again'}
    When I mark the dropped questions seen
    Then it does not say {'dropped 2 questions'}

  # A run: the provider refused, the agent ended, and the machine said "idle".
  Scenario: work whose agent was refused by its provider needs you, in the provider's words
    When the agent of {'porelo-checkout-shell'} ended with the provider's {402} {'This request requires more credits'}
    Then the first tile is {'porelo-checkout-shell'}
    And it says {'The provider refused it: no credits left (402): This request requires more credits'}
    And it does not say {'Working'}

  Scenario: work whose agent finished needs nobody
    When the agent of {'porelo-checkout-shell'} finished
    Then no tile is shown for {'porelo-checkout-shell'}

  # Walk 10: a vault that locked itself stopped every conversation, and nothing said so.
  Scenario: messages that wait because the vault is locked are said, with the projects they hold up
    Given the messages of {'checkout'} wait because {'messages wait: the vault is locked, so no conversation can be read or written: porelo vault unlock lets them go on'}
    Then it says {'Messages wait on'}
    And it says {'the vault is locked, so no conversation can be read or written'}
    And it says {'Held up: checkout'}
