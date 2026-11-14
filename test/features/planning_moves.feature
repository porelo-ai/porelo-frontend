Feature: Planning moves are saved at once

    Background:
        Given a backend with planning
        And the app is running
        When I open the planning board
        And I search planning for {'ST29'}

    # Harm: a move is saved other than the planner previewed it, or a saved story is placed where the planner did not move it.
    Scenario: A drop is previewed and saved at once
        When I drag planning story {'ST293'} to {'Review'}
        Then the planning save sent the digest its preview answered
        And no planning move warning is shown
        And planning story {'ST293'} is not being saved
        And the planning story {'ST293'} is in {'Review'}

    # Harm: issues a story move carries along are moved unseen, or a confirmed story is placed where the daemon did not set it.
    Scenario: A move that carries issues along asks first and takes the daemon confirmation
        When I drag planning story {'ST291'} to {'Review'}
        Then planning warns that {'ST291'} carries issues along
        And no planning move was saved
        When I confirm the planning move
        Then no planning move warning is shown
        And planning story {'ST291'} is not being saved
        And the planning story {'ST291'} is in {'Review'}
        When I expand planning story issues {'ST291'}
        Then advanced planning issues keep their state

    # Harm: a canceled move is saved anyway or leaves its card where it was never saved.
    Scenario: A canceled warning sends nothing
        When I drag planning story {'ST291'} to {'Review'}
        And I cancel the planning move
        Then no planning move warning is shown
        And no planning move was saved
        And planning story {'ST291'} is not being saved
        And the planning story {'ST291'} is in {'Backlog'}

    # Harm: a move in flight reads as saved before the planner answers it.
    Scenario: A move shows as saving until the planner answers
        Given the planning move reply is held
        When I drag planning story {'ST293'} to {'Review'}
        Then planning story {'ST293'} is being saved
        When the planning move reply arrives
        Then planning story {'ST293'} is not being saved
        And the planning story {'ST293'} is in {'Review'}

    # Harm: a save keeps the board's old revision, so the next move is refused as stale.
    Scenario: A saved move takes the planner's new revision for the next move
        When I drag planning story {'ST293'} to {'Review'}
        And I drag planning story {'ST293'} to {'Backlog'}
        Then no planning move error is shown
        And planning story {'ST293'} is not being saved
        And the planning story {'ST293'} is in {'Backlog'}

    # Harm: a save pushed to some repositories only hides which were pushed, or shows a board the planner no longer holds.
    Scenario: A partly saved move says so in the planner's words and reads the board again
        Given the planning save is partly saved with story {'ST293'} saved in {'Review'}
        When I drag planning story {'ST293'} to {'Review'}
        Then the planning move error says {'The repository refused the push. Pushed: porelo. Not pushed: porelo-host.'}
        And planning story {'ST293'} is not being saved
        And the planning story {'ST293'} is in {'Review'}

    # Harm: a move against a board that changed overwrites somebody else's change, or stale feedback stays after the next move.
    Scenario: A stale revision moves nothing and the next move clears its feedback
        When the planning revision changes on the machine
        And I drag planning story {'ST293'} to {'Review'}
        Then the planning move error says {'Planning changed while ST293 was moved; nothing was moved. Move it again.'}
        And planning story {'ST293'} is not being saved
        And the planning story {'ST293'} is in {'Backlog'}
        When I drag planning story {'ST293'} to {'Review'}
        Then no planning move error is shown
        And the planning story {'ST293'} is in {'Review'}

    # Harm: an unnamed refusal appears saved, or its daemon reason is hidden.
    Scenario: An unnamed refusal leaves the card where it stands with the daemon words
        Given the planning machine refuses moves with {'The board cannot be written'}
        When I drag planning story {'ST293'} to {'Review'}
        Then the planning move error says {'The board cannot be written'}
        And planning story {'ST293'} is not being saved
        And the planning story {'ST293'} is in {'Backlog'}
        When I reload planning moves
        Then the planning story {'ST293'} is in {'Backlog'}

    # Harm: a refusal naming the story hides its words or leaves the card in a destination never saved.
    Scenario: A refusal naming the story shows its words
        Given the planning save refuses {'NoSuchStory'} for story {'ST293'} with {'The story is unknown'}
        When I drag planning story {'ST293'} to {'Review'}
        Then the planning move error says {'The story is unknown'}
        And planning story {'ST293'} is not being saved
        And the planning story {'ST293'} is in {'Backlog'}

    # Harm: a refusal of one story blocks the next move of another or leaves its stale words on screen.
    Scenario: A refusal of one story leaves the next move free
        Given the planning machine refuses story {'ST291'} with {'Work is still running'}
        When I drag planning story {'ST291'} to {'Review'}
        And I confirm the planning move
        Then the planning move error says {'Work is still running'}
        And the planning story {'ST291'} is in {'Backlog'}
        When I drag planning story {'ST293'} to {'Review'}
        Then no planning move error is shown
        And the planning story {'ST293'} is in {'Review'}
        And the planning story {'ST291'} is in {'Backlog'}

    # Harm: a new move leaves the previous refusal beside its own, so a card reads as refused for a reason gone.
    Scenario: A new move clears the previous problem before showing its new refusal
        Given the planning machine refuses story {'ST293'} with {'Work is still running'}
        When I drag planning story {'ST293'} to {'Review'}
        Then the planning move error says {'Work is still running'}
        Given the planning save refuses {'AnotherRefusal'} for story {'ST293'} with {'This story cannot move'}
        When I drag planning story {'ST293'} to {'Review'}
        Then the planning move error says {'This story cannot move'}
        And the planning move error no longer says {'Work is still running'}
        And the planning story {'ST293'} is in {'Backlog'}

    # Harm: folding the refused card's column hides the daemon reason.
    Scenario: A refusal stays readable when its card is folded
        Given the planning machine refuses moves with {'Work is still running'}
        When I drag planning story {'ST293'} to {'Review'}
        And I fold the planning phase {'Backlog'}
        Then the planning move error says {'Work is still running'}

    # Harm: dropping into work starts a task without its start decision.
    Scenario: A working state requests a start and moves nothing
        When I drag planning story {'ST291'} to {'Implementing'}
        Then planning start was requested for {'ST291'} in {'Implementing'}
        And no planning move error is shown
        And no planning move was saved
        And the planning story {'ST291'} is in {'Backlog'}

    # Harm: closed states cannot receive deliberate moves from folded columns.
    Scenario: A closed destination accepts a drop
        When I search planning for {'ST293'}
        And I unfold closed planning states
        And I fold the planning phase {'Build'}
        And I drag planning story {'ST293'} to {'Finished'}
        Then planning story {'ST293'} is not being saved
        And the planning story {'ST293'} is in {'Finished'}

    # Harm: a missing target hint makes a drop ambiguous.
    Scenario: Hover names the destination
        When I hold planning story {'ST293'} over {'Review'}
        Then the planning drop hint names {'Review'}
        When I drop the planning story
        Then the planning story {'ST293'} is in {'Review'}

    # Harm: dropping work back on its own state requests another start.
    Scenario: A working card does not offer its own state as a destination
        When I search planning for {'ST27'}
        And I hold planning story {'ST27'} over {'Implementing'}
        Then no planning drop hint names {'Implementing'}
        When I drop the planning story
        Then no planning start is requested
        And no planning move was saved
        And the planning story {'ST27'} is in {'Implementing'}

    # Harm: leaving Planning while a move is saved hides whether it was saved.
    Scenario: Leaving Planning while a move is saved waits for the planner
        Given the planning move reply is held
        When I drag planning story {'ST293'} to {'Review'}
        And I try to leave planning moves
        Then planning asks to wait for the save
        When I keep editing planning moves
        Then the planning page is shown
        And planning story {'ST293'} is being saved
        When the planning move reply arrives
        And I try to leave planning moves
        Then the work page is shown

    # Harm: closing the window while a move is saved drops it unseen.
    Scenario: Closing the window while a move is saved asks first and can be canceled
        Given the planning move reply is held
        When I drag planning story {'ST293'} to {'Review'}
        And I ask to close it
        Then planning asks to wait for the save
        When I keep editing planning moves
        Then the planning window close is canceled
        And planning story {'ST293'} is being saved

    # Harm: window close stacks a second planning question over a pending navigation question.
    Scenario: Window close keeps one existing planning question
        Given the planning move reply is held
        When I drag planning story {'ST293'} to {'Review'}
        And I try to leave planning moves
        And I ask to close it
        Then planning asks to wait for the save
        When I keep editing planning moves
        Then the planning page is shown

    # Harm: leaving a move the planner answers late loses it, or shows it as saved on the return.
    Scenario: A move the planner answers late can be left and is still awaited on the return
        Given the planning save times out
        When I drag planning story {'ST293'} to {'Review'}
        Then the planning move notice says {'Still saving.'}
        When I try to leave planning moves
        Then planning asks before leaving
        When I leave planning anyway
        Then the work page is shown
        When I open the planning board
        Then planning story {'ST293'} is being saved

    # Harm: a move over running work stops it without the person being asked.
    Scenario: A move over running work warns first and Cancel stops nothing
        When I open story work for {'ST291'}
        And I choose story work {'start'}
        And I drag planning story {'ST291'} to {'Review'}
        Then planning warns that moving {'ST291'} stops its running work
        And planning warns that {'ST291'} carries issues along
        When I cancel the planning move
        Then no planning move warning is shown
        And no planning move was saved
        And nothing was stopped on this machine
        And the planning story {'ST291'} is in {'Backlog'}

    # Harm: the move leaves a task the planner stopped running, or ends one it did not name.
    Scenario: A confirmed move over running work ends exactly the tasks the planner stopped
        When I open story work for {'ST291'}
        And I choose story work {'start'}
        And I drag planning story {'ST291'} to {'Review'}
        Then planning warns that moving {'ST291'} stops its running work
        When I confirm the planning move
        Then no planning move error is shown
        And the tasks the planning save stopped were stopped on this machine
        And planning story {'ST291'} is not being saved
