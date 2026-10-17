# The Feature line is the report row: one short sentence, 70 characters at most,
# saying what this file tests. It is the group name in every surface CI renders.
Feature: Work in its machine's area, as tiles that carry their own actions

  # Work that needs nobody is not on what needs a person, so it is looked at where it lives.
  Background:
    Given a backend with work on it
    And the app is running
    And I go to the work

  Scenario: a quiet task is marked as a guess, and a known state never is
    Given the work {'porelo-checkout-shell'} is idle
    And the work {'porelo-billing-shell'} is waiting on {'api.example.test:443'}
    Then the tile {'porelo-checkout-shell'} is marked as a guess
    And the tile {'porelo-billing-shell'} is not marked as a guess

  # Which provider a task's agent was brokered to is the task's own record, said beside it.
  Scenario: work says which provider its agent was brokered to, and nothing where none is recorded
    Given the work {'porelo-checkout-shell'} runs {'an-agent'} brokered to {'github-copilot'}
    And the work {'porelo-billing-shell'} runs {'an-agent'} brokered to {''}
    Then the tile {'porelo-checkout-shell'} says {'an-agent via github-copilot'}
    And the tile {'porelo-billing-shell'} says {'an-agent'}
    And the tile {'porelo-billing-shell'} does not say {'via'}
    When I select the work {'porelo-checkout-shell'}
    And I open the selection
    Then the detail for {'porelo-checkout-shell'} is shown
    And it says {'github-copilot'}

  # Walk 8: every tile on a machine's page was headed by the same machine, and running
  # and stopped work could not be told apart at a glance.
  Scenario: a tile is headed by its work, and its state is marked by colour and shape
    Given the work {'porelo-billing-shell'} is waiting on {'api.example.test:443'}
    Then the tile {'porelo-billing-shell'} is headed by its work
    And the tile {'porelo-billing-shell'} shows the state {'question'}
    Given the work {'porelo-checkout-shell'} has stopped
    When I select the project {'checkout'}
    Then the tile {'porelo-checkout-shell'} is headed by its work
    And the tile {'porelo-checkout-shell'} shows the state {'stopped'}

  Scenario: work nothing can see is never drawn as quiet
    Given the work {'porelo-checkout-shell'} cannot be seen
    Then the tile {'porelo-checkout-shell'} says {'Running'}
    And the tile {'porelo-checkout-shell'} is not marked as a guess

  # Reported: opened from Running and put away, it came back to the work's project.
  Scenario: work is opened by hand from the work page, and leaving it comes back there
    When I work in {'porelo-checkout-shell'} by hand from its tile
    Then the session runs {'porelo task attach porelo-checkout-shell'}
    When I leave the session
    Then the view shown is the work

  Scenario: the name on a tile can be selected and copied
    Then the name on the tile {'porelo-checkout-shell'} can be copied

  Scenario: a tile offers what its work can be told to do, from its menu
    When I open the menu of the tile {'porelo-checkout-shell'}
    Then the menu offers {'Work in it by hand'}

  Scenario: clicking a tile with the right button opens the same menu
    When I click the tile {'porelo-checkout-shell'} with the right button
    Then the menu offers {'Work in it by hand'}

  # Stopped work is under its project, not under what is running.
  # The answer went only to the status line, and a start from a tile looked like nothing happened.
  Scenario: work started again from its tile says what came of it, on the tile
    Given the work {'porelo-checkout-shell'} has stopped
    When I select the project {'checkout'}
    And I choose {'Start it again'} from the menu of the tile {'porelo-checkout-shell'}
    Then {'porelo-checkout-shell'} was started again
    And the tile {'porelo-checkout-shell'} says {'is running again'}

  Scenario: a start the machine refused when pressed says so on the tile
    Given the work {'porelo-checkout-shell'} has stopped
    And starting it again will be refused because the vault is locked
    When I select the project {'checkout'}
    And I choose {'Start it again'} from the menu of the tile {'porelo-checkout-shell'}
    Then the tile {'porelo-checkout-shell'} says {'the vault is locked'}

  # Reported: only "failed with exit code 70", where the machine had said why.
  Scenario: a start that failed with an exit code says what the machine printed, on the tile
    Given the work {'porelo-checkout-shell'} has stopped
    And starting it again will fail with exit code {70} saying {'Several agents are installed'}
    When I select the project {'checkout'}
    And I choose {'Start it again'} from the menu of the tile {'porelo-checkout-shell'}
    Then the tile {'porelo-checkout-shell'} says {'Several agents are installed'}

  # The machine says beforehand what Start would do, so nobody finds a refusal by pressing.
  Scenario: a start the machine would refuse is unavailable on the tile, with its reason
    Given the work {'porelo-checkout-shell'} has stopped
    And the machine says starting {'porelo-checkout-shell'} needs the vault unlocked
    When I select the project {'checkout'}
    And I open the menu of the tile {'porelo-checkout-shell'}
    Then the menu offers {'Start it again'} as unavailable because {'vault is locked'}

  # A restart took its sockets; the machine says how to save the workspace instead.
  Scenario: work started before its machine restarted can only be recovered, and says how
    Given the work {'porelo-checkout-shell'} has stopped
    And the machine says {'porelo-checkout-shell'} was started before the machine restarted
    When I select the project {'checkout'}
    And I open the menu of the tile {'porelo-checkout-shell'}
    Then the menu offers {'Start it again'} as unavailable because {'podman cp porelo-checkout-shell:/workspace'}

  Scenario: a container named from before one per task can only be removed
    Given the work {'porelo-checkout-shell'} has stopped
    And the machine says {'porelo-checkout-shell'} has a name from before one container per task
    When I select the project {'checkout'}
    And I open the menu of the tile {'porelo-checkout-shell'}
    Then the menu offers {'Start it again'} as unavailable because {'can only be removed'}

  # Work says which of its project's repositories it is in, and saying nothing means the
  # project's own — a container from before it said so, never an unknown one.
  Scenario: a tile names the repository its work is in, once there is more than one
    Given the project {'checkout'} has the repositories {'checkout, payments-api'}
    And the work {'porelo-checkout-shell'} works in the repository {'payments-api'}
    Then the tile {'porelo-checkout-shell'} says {'in payments-api'}

  Scenario: work started again starts in the repository it worked in
    Given the project {'checkout'} has the repositories {'checkout, payments-api'}
    And the work {'porelo-checkout-shell'} works in the repository {'payments-api'}
    And the work {'porelo-checkout-shell'} has stopped
    When I select the project {'checkout'}
    And I choose {'Start it again'} from the menu of the tile {'porelo-checkout-shell'}
    Then it was started again in the repository {'payments-api'}

  Scenario: work that names no repository is in the project's own
    Given the project {'checkout'} has the repositories {'checkout, payments-api'}
    And the work {'porelo-checkout-shell'} has stopped
    When I select the project {'checkout'}
    Then the tile {'porelo-checkout-shell'} says {'in checkout'}
    When I choose {'Start it again'} from the menu of the tile {'porelo-checkout-shell'}
    Then it was started again in the repository {'checkout'}

  Scenario: a machine that names no repositories is started again in none
    Given the work {'porelo-checkout-shell'} has stopped
    When I select the project {'checkout'}
    And I choose {'Start it again'} from the menu of the tile {'porelo-checkout-shell'}
    Then it was started again in no repository

  # Porelo brings back a task its machine's restart took down, and says why it is down: in the
  # machine's words, on the tile, beside a start that is offered.
  Scenario: work a restart took down says why on its tile, and can be started again
    Given the work {'porelo-checkout-shell'} has stopped
    And the machine says a restart of its machine took {'porelo-checkout-shell'} down
    When I select the project {'checkout'}
    Then the tile {'porelo-checkout-shell'} says {'the machine restarted; starting it brings it back whole'}
    When I open the menu of the tile {'porelo-checkout-shell'}
    Then the menu offers {'Start it again'}

  Scenario: work a restart took down, started again, says what was restored
    Given the work {'porelo-checkout-shell'} has stopped
    And the machine says a restart of its machine took {'porelo-checkout-shell'} down
    When I select the project {'checkout'}
    And I choose {'Start it again'} from the menu of the tile {'porelo-checkout-shell'}
    Then the tile {'porelo-checkout-shell'} says {'its records, its egress and its tokens were restored'}

  # Unlocking is the one thing that helps, so it is offered where the refusal is.
  Scenario: work whose start needs the vault unlocked offers to unlock it
    Given the work {'porelo-checkout-shell'} has stopped
    And the machine says starting {'porelo-checkout-shell'} needs the vault unlocked
    When I select the project {'checkout'}
    And I choose {'Unlock the vault, so this can start'} from the menu of the tile {'porelo-checkout-shell'}
    Then a terminal runs {'porelo vault unlock'} on the machine

  Scenario: work that can simply be started again says nothing about a restart
    Given the work {'porelo-checkout-shell'} has stopped
    When I select the project {'checkout'}
    Then no tile says {'restarted'}
    When I open the menu of the tile {'porelo-checkout-shell'}
    Then the menu does not offer {'Unlock the vault, so this can start'}

  Scenario: work a restart took down says why in its detail too
    Given the work {'porelo-checkout-shell'} has stopped
    And the machine says a restart of its machine took {'porelo-checkout-shell'} down
    When I select the project {'checkout'}
    And I select the work {'porelo-checkout-shell'}
    And I open the selection
    Then the detail for {'porelo-checkout-shell'} is shown
    And it says {'Why it is down'}
    And it says {'the machine restarted; starting it brings it back whole'}

  # Measured on Porelo 200: a task the restart took down, whose tokens wait in a locked vault, says
  # both why it is down and that unlocking is what brings it back.
  Scenario: work a restart took down while the vault is locked says why, and offers to unlock
    Given the work {'porelo-checkout-shell'} has stopped
    And the machine says a restart took {'porelo-checkout-shell'} down and its tokens wait in the locked vault
    When I select the project {'checkout'}
    Then the tile {'porelo-checkout-shell'} says {'the machine restarted; starting it brings it back whole'}
    When I open the menu of the tile {'porelo-checkout-shell'}
    Then the menu offers {'Start it again'} as unavailable because {'vault is locked'}
    And the menu offers {'Unlock the vault, so this can start'}

  # Walk 9: what an unattended agent does is seen on its tile, small, updated now and
  # then so many tiles cost little, and enlarged to the right side when wanted.
  Scenario: a tile shows the newest lines its agent writes, drawn only now and then
    Given the work {'porelo-billing-shell'} runs unattended
    Then the tile of {'porelo-billing-shell'} shows {'Nothing written yet.'}
    When the agent of {'porelo-billing-shell'} writes {'reading the contracts'}
    Then the tile of {'porelo-billing-shell'} shows {'reading the contracts'}
    When the agent of {'porelo-billing-shell'} writes {'[read] doc/Backend-API.md'}
    Then the tile of {'porelo-billing-shell'} does not show {'[read] doc/Backend-API.md'} yet
    When {3} seconds pass
    Then the tile of {'porelo-billing-shell'} shows {'[read] doc/Backend-API.md'}
    And its tail was asked for from its last {20} lines, formatted

  Scenario: a tile's console is enlarged to the right side, following, and made small again
    Given the work {'porelo-billing-shell'} runs unattended
    When I enlarge the console of {'porelo-billing-shell'}
    Then the view shown is {'porelo-billing-shell · what its agent writes'}

  # Work in a terminal writes no log of its own; its screen comes with Porelo's Screen.
  Scenario: a tile of work in a terminal says where its agent's lines are, and reads no log
    Then the tile of {'porelo-billing-shell'} shows {'Its agent works in its terminal - open it to see.'}

  # Walk 9: work by hand shows on its tile what its terminal shows, like a picture of it,
  # asked of the machine every few seconds without attaching.
  Scenario: a tile of work in a terminal shows what its session shows, asked only every few seconds
    Given the terminal of {'porelo-billing-shell'} shows {'agent> make test'}
    Then the tile of {'porelo-billing-shell'} shows {'Its agent works in its terminal - open it to see.'}
    When {3} seconds pass
    Then the tile of {'porelo-billing-shell'} shows {'agent> make test'}
    When {9} seconds pass
    Then the screen of {'porelo-billing-shell'} was asked for at most {5} times

  # Walk 10: enlarging the console of work in a terminal opened its details, not its terminal.
  Scenario: enlarging the console of work in a terminal opens its session
    Given the terminal of {'porelo-billing-shell'} shows {'agent> make test'}
    Then the tile of {'porelo-billing-shell'} shows {'Its agent works in its terminal - open it to see.'}
    When {3} seconds pass
    And I enlarge the console of {'porelo-billing-shell'}
    Then {1} sessions are open
