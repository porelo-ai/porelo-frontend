# The Feature line is the report row: one short sentence, 70 characters at most,
# saying what this file tests. It is the group name in every surface CI renders.
Feature: Answering blocked connections, and widening what work reaches

  Background:
    Given a backend with work on it
    And the app is running
    And I go to the work

  Scenario: a blocked connection turns up without anybody going to look for it
    When work is blocked reaching {'api.example.test:443'}
    Then the rail says {'1'} is waiting

  Scenario: what was attempted, by which work, and which rule stopped it
    When work is blocked reaching {'api.example.test:443'}
    And I go to what is blocked
    Then it shows the destination {'api.example.test:443'}
    And it names the work and the rule

  Scenario: several pieces of work are watched in one view, not one view each
    When work is blocked reaching {'api.example.test:443'}
    And other work is blocked reaching {'files.example.test:22'}
    And I go to what is blocked
    Then both are shown together

  Scenario: letting one through tells the work that is waiting
    When work is blocked reaching {'api.example.test:443'}
    And I go to what is blocked
    And I let it through
    Then the answer sent was {'allow'}

  Scenario: keeping one blocked is a separate answer, not a silence
    When work is blocked reaching {'api.example.test:443'}
    And I go to what is blocked
    And I keep it blocked
    Then the answer sent was {'deny'}

  Scenario: work nothing is enforcing is marked wherever it appears
    When I select the project {'billing'}
    Then the work {'porelo-billing-audit'} is marked as unenforced
    And the work {'porelo-billing-shell'} is not marked as unenforced

  Scenario: letting one through says the host is reachable, not that the attempt succeeded
    When work is blocked reaching {'api.example.test:443'}
    And I go to what is blocked
    And I let it through
    And the answer comes back
    Then it says {'the attempt that was refused is gone'}

  Scenario: a destination asked about again says why that is not a mistake
    When work is blocked reaching {'cdn.example.test:443'}
    And I go to what is blocked
    And I let it through
    And the answer comes back
    And work is blocked reaching {'cdn.example.test:443'}
    Then it says {'remembered per address'}

  Scenario: a question that ran out says so rather than quietly disappearing
    When work is blocked reaching {'api.example.test:443'}
    And I go to what is blocked
    And the question runs out
    Then it says the question ran out
    And nothing is waiting any more

  Scenario: what running work may reach is changed from where that work is listed
    When I select the project {'checkout'}
    And I select the work {'porelo-checkout-shell'}
    And I choose the command {'Let this work reach something new'}
    And I ask it to reach {'files.example.test'}
    And I choose {'Just this run'}
    And I show what that would grant
    Then it lists the grant {'files.example.test'}
    And nothing has been granted yet

  Scenario: how far the change goes is chosen, never defaulted
    When I select the project {'checkout'}
    And I select the work {'porelo-checkout-shell'}
    And I choose the command {'Let this work reach something new'}
    And I ask it to reach {'files.example.test'}
    Then showing what it would grant is not offered yet

  Scenario: the scope that was chosen is the scope that is sent
    When I select the project {'checkout'}
    And I select the work {'porelo-checkout-shell'}
    And I choose the command {'Let this work reach something new'}
    And I ask it to reach {'files.example.test'}
    And I choose {'This run and the project file'}
    And I show what that would grant
    And I grant it
    Then the scope sent was {'RUN_AND_PROJECT'}

  Scenario: a grant says the host is reachable next time, not that what failed will now work
    When I select the project {'checkout'}
    And I select the work {'porelo-checkout-shell'}
    And I choose the command {'Let this work reach something new'}
    And I ask it to reach {'files.example.test'}
    And I choose {'Just this run'}
    And I show what that would grant
    And I grant it
    Then it says {'Reachable from the next attempt'}
    And it says {'This run only'}

  Scenario: a run widened with no project file to write is a partial success, not a failure
    When the project file cannot be found
    And I select the project {'checkout'}
    And I select the work {'porelo-checkout-shell'}
    And I choose the command {'Let this work reach something new'}
    And I ask it to reach {'files.example.test'}
    And I choose {'This run and the project file'}
    And I show what that would grant
    And I grant it
    Then it says {'Granted for this run'}
    And it says {'Reachable from the next attempt'}

  Scenario: a name refused on purpose is said as a refusal, with the machine's reason
    When the machine refuses the name {'www.iana.org'} on purpose
    And I select the project {'checkout'}
    And I select the work {'porelo-checkout-shell'}
    And I choose the command {'Let this work reach something new'}
    And I ask it to reach {'www.iana.org'}
    And I choose {'This run and the project file'}
    And I show what that would grant
    Then it says {'Refused: that name is refused on purpose'}
    And it says {'www.iana.org is refused by the project'}
    And it does not say {'Reachable from the next attempt'}
    And granting it is not offered

  Scenario: work that is not running says why it cannot be widened
    When I select the project {'checkout'}
    And I select the work {'porelo-checkout-migrate'}
    And I open the command finder
    Then the command {'Let this work reach something new'} is offered as unavailable

  Scenario: an offline project is never offered the action
    When I select the project {'billing'}
    And I select the work {'porelo-billing-shell'}
    And I open the command finder
    Then the command {'Let this work reach something new'} is offered as unavailable

  # `NarrowTask` is a method of its own. It was undecided when widening was built — taking a grant
  # back from a container that already has it is a different thing from granting one.
  Scenario: taking a name back is previewed before anything changes
    When I select the project {'checkout'}
    And I select the work {'porelo-checkout-shell'}
    And I take something back from this work
    And I say the names {'files.example.test'}
    And I choose {'Just this run'}
    And I show what that would take back
    Then it says {'files.example.test'}
    And it says {'2 addresses come out of the firewall'}
    And nothing has been taken back yet

  # The sentence this screen exists to get right: the ruleset lets established traffic through
  # without asking again, so a transfer in flight runs to its end.
  Scenario: it says that new connections stop, never that the host is unreachable
    When I select the project {'checkout'}
    And I select the work {'porelo-checkout-shell'}
    And I take something back from this work
    Then it says {'This stops new connections'}
    And it says {'a transfer already in flight runs to its end'}
    And it says {'stopping the task is what does that'}

  Scenario: taking it back says how far it went
    When I select the project {'checkout'}
    And I select the work {'porelo-checkout-shell'}
    And I take something back from this work
    And I say the names {'files.example.test'}
    And I choose {'This run and the project'}
    And I show what that would take back
    And I take it back
    Then it says {'Taken back: files.example.test'}
    And it says {'The project file is changed too'}

  # A real state and not a failure: the name was granted and the container never reached it, so
  # nothing was in the set to remove.
  Scenario: a name that was never reached takes nothing out of the firewall
    Given taking back will find nothing in the firewall
    When I select the project {'checkout'}
    And I select the work {'porelo-checkout-shell'}
    And I take something back from this work
    And I say the names {'files.example.test'}
    And I choose {'Just this run'}
    And I show what that would take back
    Then it says {'it was granted and never reached'}

  Scenario: work that is not running is not offered it
    When I select the project {'checkout'}
    And I select the work {'porelo-checkout-migrate'}
    And I open the command finder
    Then the command {'Take something back from this work'} is offered as unavailable

  # `SetClearance` closed the one criterion that had no method. It was
  # deliberately not folded into widening: those grant and withdraw names, and that the firewall
  # stays loaded is what they mean.
  Scenario: enforcement is turned off on work that is already running
    When I select the project {'checkout'}
    And I select the work {'porelo-checkout-shell'}
    And I change what this work does with a blocked connection
    And I choose to {'Stop asking entirely'}
    Then the work was set to {'off'}
    And the status line mentions {'went from “prompt” to “off”'}

  # The sentence nothing else says: the ruleset is loaded either way, so this opens nothing by
  # itself — and it undoes nothing that already happened.
  Scenario: it says what turning it off does not undo
    When I select the project {'checkout'}
    And I select the work {'porelo-checkout-shell'}
    And I change what this work does with a blocked connection
    Then it says {'a connection that was refused stays refused'}
    And it says {'The ruleset is loaded either way'}

  # Not a failure: it was already in that mode and nothing was restarted.
  Scenario: asking for the mode it is already in is not reported as a change
    When I select the project {'billing'}
    And I select the work {'porelo-billing-audit'}
    And I change what this work does with a blocked connection
    And I choose to {'Stop asking entirely'}
    Then the status line mentions {'was already doing that'}

  Scenario: work that is not running is not offered it
    When I select the project {'checkout'}
    And I select the work {'porelo-checkout-migrate'}
    And I open the command finder
    Then the command {'Change what this work does with a blocked connection'} is offered as unavailable
