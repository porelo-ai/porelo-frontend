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

    # Harm: a move that landed elsewhere meanwhile reads as refused, and the person moves it again.
    Scenario: A save that meets planning already showing the target state counts as done
        Given the planning save meets a changed planning showing story {'ST293'} in {'Review'}
        When I drag planning story {'ST293'} to {'Review'}
        Then the planning move notice says {'Planning already shows ST293 in Review.'}
        And no planning move error is shown
        And planning story {'ST293'} is not being saved
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

    # Harm: a story finished on the board leaves its issues in Review, or the person is not told their files go.
    Scenario: A story finished takes its issues in Review along, said with their files deleted
        When I search planning for {'ST10'}
        And I unfold closed planning states
        And I drag planning story {'ST10'} to {'Finished'}
        Then planning warns that {'ST10'} carries issues along whose files are deleted
        When I confirm the planning move
        Then no planning move warning is shown
        And planning story {'ST10'} is not being saved
        And the planning story {'ST10'} is in {'Finished'}
        When I expand planning story issues {'ST10'}
        Then planning issues {'HO12 BT24 BT25'} of {'ST10'} are in {'Finished'}

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

    # Harm: a move of a story whose tasks all ended asks to stop a start the planner was told of long ago.
    Scenario: A move after the started tasks ended warns of no start still handed on
        When I open story work for {'ST291'}
        And I choose story work {'start'}
        Given story work is prepared with {'every started task ended'}
        When I drag planning story {'ST291'} to {'Review'}
        Then planning does not warn that moving {'ST291'} stops work
        And planning warns that {'ST291'} carries issues along

    # Harm: the reader the planner orders after a reported start is started twice, or not at all.
    Scenario: A follow-up the planner orders after a reported start is started once
        Given the planner orders a reader of {'B540'} after the next reported start
        When I open story work for {'ST291'}
        And I choose story work {'start'}
        Then the reader the planner ordered of {'B540'} was started once on this machine

    # Harm: a report the planner never took is kept as taken, as another task of the story was pressed meanwhile, and is
    # never sent again.
    Scenario: A started report refused while another task is pressed is not kept as taken
        Given the planner holds the next started report
        When I open story work for {'ST291'}
        And I choose story work {'start'}
        And another task of {'ST291'} reading {'B540'} is pressed on the board
        And the planner refuses the held report
        Then the start of the held report is not kept as reported

    # Harm: a report the planner took is sent again, and what its answer orders started beside the board's run, when
    # that run cannot start it.
    Scenario: A follow-up the run refuses after a taken report sends the report once
        When I open story work for {'ST291'}
        And I choose story work {'start'}
        Given the planner orders a started task of {'ST291'} reading {'B553'} after every reported start
        When I open story work for {'ST292'}
        And I choose story work {'start'}
        Then each start of {'ST292'} was reported once
        And no ordered task was started twice on this machine

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
