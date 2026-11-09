Feature: Planning moves stay pending until saved

    Background:
        Given a backend with planning
        And the app is running
        When I open the planning board
        And I search planning for {'ST29'}

    # Harm: a drag writes unreviewed work and undo loses the original state.
    Scenario: Drag and undo without writing to the machine
        When I drag planning story {'ST291'} to {'Review'}
        Then the planning story {'ST291'} is in {'Review'}
        And planning story {'ST291'} has a pending move
        When I undo planning story {'ST291'}
        Then the planning story {'ST291'} is in {'Backlog'}
        And planning story {'ST291'} has no pending move

    # Harm: undo removes unrelated pending decisions.
    Scenario: Undo one of several pending moves
        When I drag planning story {'ST291'} to {'Review'}
        And I drag planning story {'ST292'} to {'Review'}
        And I undo planning story {'ST291'}
        Then the planning story {'ST291'} is in {'Backlog'}
        And planning story {'ST291'} has no pending move
        And planning story {'ST292'} has a pending move
        And the planning story {'ST292'} is in {'Review'}

    # Harm: a saved story is placed where the daemon did not move it or moves advanced issues back.
    Scenario: Save uses the daemon confirmation and preserves advanced issues
        When I drag planning story {'ST291'} to {'Review'}
        And I save planning moves
        Then planning story {'ST291'} has no pending move
        And the planning story {'ST291'} is in {'Review'}
        When I expand planning story issues {'ST291'}
        Then advanced planning issues keep their state

    # Harm: a batch partly commits or its cards do not take the daemon answer.
    Scenario: Save several stories atomically
        When I drag planning story {'ST291'} to {'Review'}
        And I drag planning story {'ST292'} to {'Review'}
        And I save planning moves
        Then planning story {'ST291'} has no pending move
        And planning story {'ST292'} has no pending move
        And the planning story {'ST291'} is in {'Review'}
        And the planning story {'ST292'} is in {'Review'}

    # Harm: stale intent overwrites somebody else's planning change or is silently lost.
    Scenario: A stale revision rereads and keeps the remaining intent usable
        When I drag planning story {'ST291'} to {'Review'}
        And the planning revision changes on the machine
        And I save planning moves
        Then the planning move error says {'Planning changed since this board was read'}
        And planning story {'ST291'} has a pending move
        And planning Save is usable
        When I save planning moves
        Then planning story {'ST291'} has no pending move
        And the planning story {'ST291'} is in {'Review'}

    # Harm: a refused move appears saved or its daemon reason is hidden.
    Scenario: A refusal keeps the pending move and the daemon words
        Given the planning machine refuses moves with {'Work is still running'}
        When I drag planning story {'ST291'} to {'Review'}
        And I save planning moves
        Then planning story {'ST291'} shows refusal {'Work is still running'}
        And planning story {'ST291'} has a pending move
        And the planning story {'ST291'} is in {'Backlog'}
        And planning story {'ST291'} is not marked moved
        And planning Save is usable
        When I reload planning moves
        Then planning story {'ST291'} shows refusal {'Work is still running'}
        And the planning story {'ST291'} is in {'Backlog'}
        And planning story {'ST291'} is not marked moved

    # Harm: dropping into work starts a task without its start decision.
    Scenario: A working state requests a start and moves nothing
        When I drag planning story {'ST291'} to {'Implementing'}
        Then planning start was requested for {'ST291'} in {'Implementing'}
        And no planning move error is shown
        And planning story {'ST291'} has no pending move
        And the planning story {'ST291'} is in {'Backlog'}

    # Harm: closed states cannot receive deliberate moves from folded columns.
    Scenario: A closed destination accepts a pending drop
        When I show closed planning states
        And I drag planning story {'ST291'} to {'Finished'}
        Then planning story {'ST291'} has a pending move
        And the planning story {'ST291'} is in {'Finished'}

    # Harm: leaving Planning silently loses unsaved decisions.
    Scenario: Leaving Planning asks first and can be canceled
        When I drag planning story {'ST291'} to {'Review'}
        And I try to leave planning moves
        Then planning asks before leaving
        When I keep editing planning moves
        Then the planning page is shown
        And planning story {'ST291'} has a pending move

    # Harm: closing the window silently drops unsaved planning decisions.
    Scenario: Closing the window asks first and can be canceled
        When I drag planning story {'ST291'} to {'Review'}
        And I ask to close it
        Then planning asks before leaving
        When I keep editing planning moves
        Then the planning window close is canceled
        And planning story {'ST291'} has a pending move

    # Harm: confirming navigation loses staged work when Planning is opened again.
    Scenario: Confirmed navigation keeps moves pending for the return
        When I drag planning story {'ST291'} to {'Review'}
        And I try to leave planning moves
        And I leave planning moves pending
        Then the work page is shown
        When I open the planning board
        Then planning story {'ST291'} has a pending move
        And the planning story {'ST291'} is in {'Review'}

    # Harm: a missing target hint makes a drop ambiguous and Undo all loses only part of the batch.
    Scenario: Hover names the destination and Undo all restores every card
        When I hold planning story {'ST291'} over {'Review'}
        Then the planning drop hint names {'Review'}
        When I drop the planning story
        And I drag planning story {'ST292'} to {'Review'}
        Then planning story {'ST291'} is marked moved
        And planning story {'ST292'} is marked moved
        When I undo all planning moves
        Then planning story {'ST291'} has no pending move
        And planning story {'ST292'} has no pending move
        And the planning story {'ST291'} is in {'Backlog'}
        And the planning story {'ST292'} is in {'Backlog'}

    # Harm: undoing a refused card blocks another pending decision or leaves a stale error on screen.
    Scenario: Undo a refusal and save the other card
        Given the planning machine refuses story {'ST291'} with {'Work is still running'}
        When I drag planning story {'ST291'} to {'Review'}
        And I drag planning story {'ST292'} to {'Review'}
        And I save planning moves
        Then planning story {'ST291'} shows refusal {'Work is still running'}
        And planning story {'ST292'} is marked moved
        When I undo planning story {'ST291'}
        Then no planning move error is shown
        And planning Save is usable
        When I save planning moves
        Then planning story {'ST292'} has no pending move
        And the planning story {'ST292'} is in {'Review'}
        And the planning story {'ST291'} is in {'Backlog'}

    # Harm: folding a refused card hides its daemon reason or marks it as moved again.
    Scenario: A folded refused card keeps its own reason
        Given the planning machine refuses moves with {'Work is still running'}
        When I drag planning story {'ST291'} to {'Review'}
        And I save planning moves
        And I fold the planning phase {'Backlog'}
        Then planning story {'ST291'} shows refusal {'Work is still running'}
        And planning story {'ST291'} is not marked moved

    # Harm: window close stacks a second planning question over a pending navigation question.
    Scenario: Window close keeps one existing planning question
        When I drag planning story {'ST291'} to {'Review'}
        And I try to leave planning moves
        And I ask to close it
        Then planning asks before leaving
        When I keep editing planning moves
        Then the planning page is shown
        And planning story {'ST291'} has a pending move

    # Harm: an unknown-story refusal leaves its card in a destination the daemon rejected.
    Scenario: An unknown-story refusal stays beside the named card
        Given the planning save refuses {'NoSuchStory'} for story {'ST291'} with {'The story is unknown'}
        When I drag planning story {'ST291'} to {'Review'}
        And I drag planning story {'ST292'} to {'Review'}
        And I save planning moves
        Then planning story {'ST291'} shows refusal {'The story is unknown'}
        And planning story {'ST291'} is not marked moved
        And the planning story {'ST291'} is in {'Backlog'}
        And planning story {'ST292'} is marked moved

    # Harm: an unnamed batch refusal leaves all refused cards marked as moved.
    Scenario: An unnamed refusal returns every submitted card to its reported column
        Given the planning machine refuses moves with {'The board cannot be written'}
        When I drag planning story {'ST291'} to {'Review'}
        And I drag planning story {'ST292'} to {'Review'}
        And I save planning moves
        Then planning story {'ST291'} shows refusal {'The board cannot be written'}
        And planning story {'ST292'} shows refusal {'The board cannot be written'}
        And planning story {'ST291'} is not marked moved
        And planning story {'ST292'} is not marked moved
        And the planning story {'ST291'} is in {'Backlog'}
        And the planning story {'ST292'} is in {'Backlog'}

    # Harm: retrying leaves the previous refusal on a card the new answer did not refuse.
    Scenario: A new save clears the previous problems before showing its new refusal
        Given the planning machine refuses story {'ST291'} with {'Work is still running'}
        When I drag planning story {'ST291'} to {'Review'}
        And I drag planning story {'ST292'} to {'Review'}
        And I save planning moves
        Then planning story {'ST291'} shows refusal {'Work is still running'}
        Given the planning save refuses {'AnotherRefusal'} for story {'ST292'} with {'This story cannot move'}
        When I save planning moves
        Then planning story {'ST291'} is marked moved
        And the planning story {'ST291'} is in {'Review'}
        And planning story {'ST292'} shows refusal {'This story cannot move'}
        And planning story {'ST292'} is not marked moved
        And the planning story {'ST292'} is in {'Backlog'}

    # Harm: undoing all intent leaves a stale refusal banner on a board with nothing to save.
    Scenario: Undo all clears the stale save feedback
        When I drag planning story {'ST291'} to {'Review'}
        And the planning revision changes on the machine
        And I save planning moves
        Then the planning move error says {'Planning changed since this board was read'}
        When I undo all planning moves
        Then no planning move error is shown
        And planning story {'ST291'} has no pending move
        And the planning story {'ST291'} is in {'Backlog'}

    # Harm: dropping work back on its own state requests another start.
    Scenario: A working card does not offer its own state as a destination
        When I search planning for {'ST27'}
        And I hold planning story {'ST27'} over {'Implementing'}
        Then no planning drop hint names {'Implementing'}
        When I drop the planning story
        Then no planning start is requested
        And planning story {'ST27'} has no pending move
        And the planning story {'ST27'} is in {'Implementing'}
