Feature: The stories of a project on a planning board

    Background:
        Given a backend with planning
        And the app is running

    # Harm: planning work is invisible or placed in a state the machine did not report.
    Scenario: A story stands in the state the machine reports
        When I open the planning board
        Then the planning story {'ST291'} is in {'Backlog'}
        And the planning phases follow the workflow
        And the planning states put working states first

    # Harm: a renamed workflow loses stories or leaves them under an obsolete state.
    Scenario: A renamed state arrives with its stories
        When I open the planning board
        And the planning state is renamed on the machine
        Then the planning story {'ST294'} is in {'Investigating'}
        And the old planning state is absent

    # Harm: less important work obscures work that must be handled first.
    Scenario: Stories sort by priority and then their number
        When I open the planning board
        Then the planning build stories are sorted

    # Harm: folding hides the amount and urgency of waiting work.
    Scenario: A folded phase retains its count and priority marks
        When I open the planning board
        And I fold the planning phase {'Build'}
        Then the folded planning build retains its count and marks

    # Harm: closed work crowds current work or cannot be found again.
    Scenario: Closed states can be revealed
        When I open the planning board
        Then closed planning states are hidden
        When I show closed planning states
        Then closed planning states are shown

    # Harm: another person changes the board while the window keeps an obsolete snapshot.
    Scenario: A changed watch answer replaces the board without reload
        When I open the planning board
        And the machine moves a planning story
        Then the planning story {'ST291'} is in {'Review'}
        And the moved planning story is absent from backlog

    # Harm: unsupported methods leave the page spinning or offer unusable controls.
    Scenario: An older machine does not offer planning
        Given the machine has no planning
        When I open the planning board
        Then the machine does not offer planning

    # Harm: a daemon refusal is hidden behind a board that still looks current.
    Scenario: A watch failure is shown in the machine words
        When I open the planning board
        And the planning watch fails
        Then the planning error says {'Planning store cannot be read'}

    # Harm: a finished watch leaves a frozen board looking live.
    Scenario: An ended watch is shown
        When I open the planning board
        And the planning watch ends
        Then the planning error says {'The planning watch ended'}

    # Harm: filters conceal or retain work outside the chosen priority and search.
    Scenario: Priority and search narrow the board
        When I open the planning board
        And I filter planning to high and above
        Then low priority planning stories are hidden
        When I search planning for {'ST291'}
        Then only the searched planning story remains

    # Harm: a narrow window makes planning controls unreachable or crashes its layout.
    Scenario: Planning remains usable in a narrow window
        When I open the planning board
        And the window is {390} pixels wide
        Then the planning search is reachable

    # Harm: a failed preferred provider hides an available current board elsewhere.
    Scenario: A live provider supplies the board when the preferred watch fails
        Given another machine offers the same project planning
        When I open the planning board
        And the planning watch fails
        Then the other planning provider supplies the board

    # Harm: a planning failure leaves updates stopped until the whole machine reconnects.
    Scenario: Planning can be retried while the machine stays connected
        When I open the planning board
        And the planning watch fails
        And I retry planning
        And the machine moves a planning story
        Then the planning story {'ST291'} is in {'Review'}

    # Harm: inferred rounds hide how many readings the machine has actually run.
    Scenario: Reading rounds come from the machine for Reading and Reworking
        When I open the planning board
        And the machine reports issues in Reading and Reworking
        Then the planning story {'ST291'} shows reading {'2 of 5, 4 of 7'}

    # Harm: a stopped reading stays unnoticed and cannot be reached for a decision.
    Scenario: Stopped reading leads to Needs you
        When I open the planning board
        And the machine reports a stopped reading
        Then the planning reading of {'ST291'} needs attention
        When I press the planning reading of {'ST291'}
        Then the section shown is {'Needs you'}
