Feature: Start and decide story work from the planning board

    Background:
        Given a backend with planning
        And the app is running
        When I open the planning board

    # Harm: a mode the project forbids starts unattended work.
    Scenario: The proposal limits modes and supplies tasks and rounds
        Given story work is prepared with {'only unattended'}
        When I open story work for {'ST291'}
        Then story work proves {'proposal defaults and allowed modes'}

    # Harm: canceling a proposal still starts tasks.
    Scenario: Cancel starts nothing
        When I open story work for {'ST291'}
        And I choose story work {'cancel'}
        Then story work proves {'nothing started'}

    # Harm: a reader is silently dropped without explaining the decision.
    Scenario: Dropping the reader requires a comment
        When I open story work for {'ST291'}
        And I choose story work {'drop reader'}
        Then story work proves {'start disabled'}
        When I choose story work {'comment and start'}
        Then story work proves {'running work visible'}

    # Harm: a changed model or reading limit is lost before start.
    Scenario: Changed participants and reading limits reach the daemon
        When I open story work for {'ST291'}
        And I choose story work {'change reader and rounds'}
        And I choose story work {'refold issue rounds'}
        Then story work proves {'per issue rounds retained'}
        And story work proves {'start disabled'}
        When I choose story work {'comment and start'}
        Then story work proves {'running work visible'}

    # Harm: a refusal moves the story and hides why nothing started.
    Scenario: A refused start shows the daemon detail
        When I open story work for {'ST291'}
        Given story work is prepared with {'start refused'}
        When I choose story work {'start'}
        Then story work proves {'refusal and original board'}

    # Harm: a proposal starts work after another person changes the board.
    Scenario: A changed board invalidates the proposal
        When I open story work for {'ST291'}
        Given story work is prepared with {'new revision'}
        Then story work proves {'start disabled'}

    # Harm: stopped work appears to have moved to a completed state.
    Scenario: Stop leaves the story in its working state
        When I open story work for {'ST291'}
        And I choose story work {'start'}
        And I choose story work {'stop'}
        Then story work proves {'stopped in working state'}

    # Harm: a blocked story outcome goes unseen and loses the agent's words.
    Scenario: Ended work appears in Needs you
        Given story work is prepared with {'ended blocked'}
        When I choose story work {'needs you'}
        Then story work proves {'ended reason visible'}

    # Harm: a stopped reading is accepted without seeing its blocking findings.
    Scenario: Review anyway sends the current reading decision
        Given story work is prepared with {'stopped reading'}
        When I choose story work {'needs you'}
        Then story work proves {'blocking findings first'}
        When I resolve the story reading with {'REVIEW_ANYWAY'}
        Then story work proves {'reading removed from open attention'}

    # Harm: an extra reading round is lost or repeated before the board confirms it.
    Scenario: One more round waits for the board echo
        Given story work is prepared with {'stopped reading without echo'}
        When I choose story work {'needs you'}
        And I resolve the story reading with {'ONE_MORE_ROUND'}
        Then story work proves {'decision waits for echo'}

    # Harm: rework begins without the person's instructions.
    Scenario: Rework requires text
        Given story work is prepared with {'stopped reading'}
        When I choose story work {'needs you'}
        And I resolve the story reading with {'REWORK'}
        Then story work proves {'rework text required'}
        When I choose story work {'send rework text'}
        Then story work proves {'rework resolved on screen'}

    # Harm: a reading refusal removes the row or hides the daemon's detail.
    Scenario: A reading refusal leaves the decision visible
        Given story work is prepared with {'stopped reading'}
        When I choose story work {'needs you'}
        Given story work is prepared with {'reading refused'}
        When I resolve the story reading with {'REVIEW_ANYWAY'}
        Then story work proves {'reading refusal visible'}

    # Harm: losing the planning watch is mistaken for resolving a stopped reading.
    Scenario: A stale reading stays visible with decisions disabled
        Given story work is prepared with {'stopped reading'}
        When I choose story work {'needs you'}
        And the planning watch fails
        Then story work proves {'stale reading retained'}

    # Harm: a narrow window makes a start decision unreachable.
    Scenario: Start is usable in a narrow window
        When I open story work in a narrow host
        Then story work proves {'narrow dialog usable'}

    # Harm: a changed main model is never started or unnecessarily requires a comment.
    Scenario: A main agent model can be changed
        When I open story work for {'ST291'}
        And I choose story work {'change main agent'}
        And I choose story work {'change main model'}
        Then story work proves {'main model visible'}
        When I choose story work {'start'}
        Then story work proves {'started main model visible'}

    # Harm: a task started With you is never opened, or another task's terminal opens in its place.
    Scenario: With you opens the terminal of the task the window started
        When I open story work for {'ST291'}
        And I choose story work {'with you'}
        And I choose story work {'start'}
        Then story work proves {'with you terminal'}

    # Harm: a dropped story moves to a working state without choosing its work.
    Scenario: Dropping on a working state opens its proposal
        When I drop story {'ST291'} on working state {'In analysis'}
        Then story work proves {'drop dialog visible'}

    # Harm: selecting another machine starts its work with the previous machine's proposal.
    Scenario: Selecting a machine reads its own proposal
        Given another machine offers the same project planning
        And story work is prepared with {'second machine proposal'}
        When I open story work for {'ST291'}
        And I choose story work {'other machine'}
        Then story work proves {'other machine proposal visible'}

    # Harm: an ended task hides the agent's last answer behind a generic ended status.
    Scenario: An ended task shows the last answer
        Given story work is prepared with {'ended task answer'}
        When I choose story work {'needs you'}
        And I choose story work {'expand attention'}
        Then story work proves {'ended task answer visible'}

    # Harm: missing work metadata is interpreted as permission to start another run.
    Scenario: Unknown work does not offer Start
        Given story work is prepared with {'unknown work'}
        When I choose story work {'open story menu'}
        Then story work proves {'start unavailable'}

    # Harm: waiting stories lose their start action and show a false work warning.
    Scenario: Waiting stories without work can start
        Then story work proves {'waiting card quiet'}
        When I choose story work {'open story menu'}
        Then story work proves {'start available'}

    # Harm: closed stories without work acquire a false work warning or cannot be started.
    Scenario: Closed stories without work can start
        Given story work is prepared with {'closed story'}
        When I choose story work {'show closed cards'}
        Then story work proves {'closed card quiet'}
        When I choose story work {'open story menu'}
        Then story work proves {'start available'}

    # Harm: missing work in a working state looks idle and permits a duplicate start.
    Scenario: A working story without work says the status is missing
        Given story work is prepared with {'working without work'}
        Then story work proves {'working work missing'}
        When I choose story work {'open story menu'}
        Then story work proves {'start unavailable'}

    # Harm: changing only an agent loses its proposed model or an unchanged Change silently starts.
    Scenario: Sub-agent Change begins with the proposal and requires a difference
        When I open story work for {'ST291'}
        And I choose story work {'change reader'}
        Then story work proves {'change proposal prefilled'}
        When I choose story work {'comment'}
        Then story work proves {'start disabled'}
        When I choose story work {'change reader agent'}
        And I choose story work {'start'}
        Then story work proves {'running work visible'}
