# The Feature line is the report row: one short sentence, 70 characters at most,
# saying what this file tests. It is the group name in every surface CI renders.
Feature: Reading and deciding about what work says to other work

    # Asked of the machine, never gathered from the stream: Talk replays nothing, so a message held
    # before the interface started would otherwise be missing, and the view would say nothing waits.
    Scenario: a message held before the interface started is in what needs a person, and counted
        Given a backend with work on it
        And {'porelo-checkout-shell'} has a message held for {'reviewer'} saying {'please look at the diff'}
        And the app is running
        And I go to what needs a person
        Then what needs a person shows a message from {'porelo-checkout-shell'}
        And the count of what needs a person is {'1 need you'}

    Scenario: a message held while the interface watches arrives without asking
        Given a backend with work on it
        And the app is running
        And I go to what needs a person
        When {'porelo-checkout-shell'} has a message held for {'reviewer'} while I watch
        Then what needs a person shows a message from {'porelo-checkout-shell'}

    # A message nobody has cleared is evidence, not content: nothing in it is rendered or followed.
    Scenario: a held message is read in full, as text, and nothing in it is interpreted
        Given a backend with work on it
        And {'porelo-checkout-shell'} has a message held for {'reviewer'} saying {'**now** [see](https://evil.example/x) <b>here</b>'}
        And the app is running
        And I go to what needs a person
        When I read the message from {'porelo-checkout-shell'}
        Then the message reads exactly {'**now** [see](https://evil.example/x) <b>here</b>'}
        And nothing in the message can be pressed
        And it says {'Held until somebody reads it'}

    # What was read is what is decided: the decision names the file that was on screen.
    Scenario: releasing a message names the message that was read
        Given a backend with work on it
        And {'porelo-checkout-shell'} has a message held for {'reviewer'} saying {'please look at the diff'}
        And the app is running
        And I go to what needs a person
        When I read the message from {'porelo-checkout-shell'}
        And I release the message
        Then the machine was told to release {'msg-1.json'} of {'porelo-checkout-shell'}
        And it says {'Released. It goes out on the next pass, unless its peer is set to refuse everything.'}
        # Closed once decided (walk 8): the outcome is said in the window behind it.
        And the message is no longer open
        And what needs a person shows no message
        And nothing needs me

    Scenario: refusing a message refuses it for good
        Given a backend with work on it
        And {'porelo-checkout-shell'} has a message held for {'reviewer'} saying {'please look at the diff'}
        And the app is running
        And I go to what needs a person
        When I read the message from {'porelo-checkout-shell'}
        And I refuse the message
        Then the machine was told to refuse {'msg-1.json'} of {'porelo-checkout-shell'}
        And it says {'Refused for good'}
        And it does not say {'with your words'}

    # A refusal with a person's own words hands them to the one that wrote it, so its agent knows why.
    Scenario: a refusal can say why, and the one that wrote it is told those words
        Given a backend with work on it
        And {'porelo-checkout-shell'} has a message held for {'reviewer'} saying {'please look at the diff'}
        And the app is running
        And I go to what needs a person
        When I read the message from {'porelo-checkout-shell'}
        And I refuse the message, saying {'not before the tests pass'}
        Then the machine was told to refuse {'msg-1.json'} of {'porelo-checkout-shell'}
        And the refusal gave the reason {'not before the tests pass'}
        And it says {'The task that wrote it is told, with your words.'}

    # Tell: the person's own words into the task's inbox, where its agent reads, never out of the machine.
    Scenario: a person writes to a task's own agent, straight into its inbox
        Given a backend with work on it
        And the app is running
        And I go to the work
        And I select the project {'checkout'}
        When I choose {'Write to its agent'} from the menu of the tile {'porelo-checkout-migrate'}
        And I put {'stop the migration, the schema changed'} in its inbox
        Then a person told {'porelo-checkout-migrate'} {'stop the migration, the schema changed'}
        And the status line mentions {'Written into the inbox of porelo-checkout-migrate'}

    Scenario: writing to a task's agent needs words, and cancelling writes nothing
        Given a backend with work on it
        And the app is running
        When I choose {'Write to its agent'} from the menu of the tile {'porelo-checkout-migrate'}
        Then putting it in its inbox is not offered yet
        And I cancel the words
        And nobody told any task anything

    Scenario: leaving a message for now decides nothing
        Given a backend with work on it
        And {'porelo-checkout-shell'} has a message held for {'reviewer'} saying {'please look at the diff'}
        And the app is running
        And I go to what needs a person
        When I read the message from {'porelo-checkout-shell'}
        And I leave the message for now
        Then nothing was decided about any message
        And what needs a person shows a message from {'porelo-checkout-shell'}

    # Decided: a refused message is read in full, and a person may still
    # deliver it. It is then said as delivered despite the filter, never as released.
    # Walk 8: "Held until…" said less than what the message says. Its text is not shown
    # before a person opens it where the filter refused it: that text is what the filter kept back.
    Scenario: a held message shows the start of its text in its row, one the filter refused never does
        Given a backend with work on it
        And {'porelo-checkout-shell'} has a message held for {'reviewer'} saying {'please look at the diff'}
        And {'porelo-billing-shell'} has a message the filter refused, for {'partner'}, saying {'key AKIA0000'}
        And the app is running
        And I go to what needs a person
        Then the row of the message from {'porelo-checkout-shell'} previews {'please look at the diff'}
        And the row of the message from {'porelo-billing-shell'} previews {''}

    Scenario: a message the filter refused is read in full, and can be delivered despite the filter
        Given a backend with work on it
        And {'porelo-checkout-shell'} has a message the filter refused, for {'partner'}, saying {'key AKIA0000'}
        And the app is running
        And I go to what needs a person
        When I read the message from {'porelo-checkout-shell'}
        Then the message reads exactly {'key AKIA0000'}
        And it says {'rule aws-key'}
        And it says {'checks it again with its own filter'}
        And the message can be delivered despite the filter or kept refused
        When I release the message
        Then the machine was told to release {'msg-1.json'} of {'porelo-checkout-shell'}
        And it says {'Delivered despite the filter'}

    # Porelo's condition: what the filter could not check is never offered.
    Scenario: a message the filter could not check is not offered for delivery
        Given a backend with work on it
        And {'porelo-checkout-shell'} has a message the filter could not check
        And the app is running
        And I go to what needs a person
        Then what needs a person shows no message
        And nothing needs me

    Scenario: a message decided somewhere else meanwhile is said to be gone, and nothing is decided
        Given a backend with work on it
        And {'porelo-checkout-shell'} has a message held for {'reviewer'} saying {'please look at the diff'}
        And the app is running
        And I go to what needs a person
        And the message was decided somewhere else
        When I read the message from {'porelo-checkout-shell'}
        Then it says {'It is no longer there'}
        And the message cannot be decided here

    # An older daemon cannot list them, and saying nothing would read as nothing waiting.
    Scenario: a machine that cannot list held messages says so, rather than showing none
        Given a backend with work on it
        And the machine cannot list held messages
        And the app is running
        And I go to what needs a person
        Then it says {'cannot list the messages held for a person'}

    # Whom a task may talk to follows from its project; here each peer is moderated. A peer is never
    # shown as reachable while everything to it waits.
    # Walk 9: whom work may talk to and what is asked is the project's file; here only the brake.
    Scenario: the peers of a task's project are listed, each with its brake, and the rules are said to be in the project's file
        Given a backend with work on it
        And {'porelo-checkout-migrate'} may talk to {'reviewer'}, {'vouched'}, in {'prompt'}
        And {'porelo-checkout-migrate'} may talk to {'partner'}, {'external'}, in {'allow'}, held
        And the app is running
        When I choose {"Hold its project's messages to a peer"} from the menu of the tile {'porelo-checkout-migrate'}
        Then the peer {'reviewer'} is not held
        And the peer {'partner'} is held
        And it says {'Holding applies to every task of checkout, including one started later'}
        And it says {"is set in the project's project.yml"}
        And it says {'in its repository'}
        And it does not say {'under Settings on its page'}
        And it does not say {'External: what arrives from it is checked again here'}

    # Walk 8: "Written to alice" read as writing to oneself; who a peer is had to be guessed from `matrix:`.
    Scenario: who a peer in the project's conversation is, is said
        Given a backend with work on it
        And {'porelo-checkout-migrate'} may talk to {'alice'} through the project's conversation, {'external'}
        And {'porelo-checkout-migrate'} may talk to {'reader'} through the project's conversation, {'vouched'}
        And the app is running
        When I choose {"Hold its project's messages to a peer"} from the menu of the tile {'porelo-checkout-migrate'}
        Then it says {'Whoever reads this project’s conversation in a matrix client, by the name alice'}
        And it says {'Another piece of work in this project'}

    # `off` is said as what it is: nothing is asked, and the filter still runs.
    # Outside an online project that is refused, and the daemon's own sentence names the setting.
    Scenario: holding everything for a peer is asked of the machine, and the peer is shown as waiting
        Given a backend with work on it
        And {'porelo-checkout-migrate'} may talk to {'reviewer'}, {'vouched'}, in {'allow'}
        And the app is running
        When I choose {"Hold its project's messages to a peer"} from the menu of the tile {'porelo-checkout-migrate'}
        And I hold everything for {'reviewer'}
        Then the machine was told to hold {'reviewer'} of {'porelo-checkout-migrate'} in {'checkout'}
        And the peer {'reviewer'} is held

    # Written, never sent: a person's message goes through the same filter and moderation.
    Scenario: a task whose project names no peers is said to talk to nobody
        Given a backend with work on it
        And the app is running
        When I choose {"Hold its project's messages to a peer"} from the menu of the tile {'porelo-checkout-migrate'}
        Then it says {'names no peers, so it may talk to nobody'}

    # Followed live from Talk and filtered here per task. The stream never carries what a message
    # said, and replays nothing, which the view says rather than showing a history it does not have.
    Scenario: what happened to a task's messages is followed live, for that task only, and never what they said
        Given a backend with work on it
        And {'porelo-checkout-migrate'} may talk to {'reviewer'}, {'vouched'}, in {'prompt'}
        And the app is running
        When the machine says {'msg-7.json'} of {'porelo-checkout-migrate'} was {'overridden'}
        And the machine says {'msg-8.json'} of {'porelo-checkout-shell'} was {'sent'}
        And I choose {"Hold its project's messages to a peer"} from the menu of the tile {'porelo-checkout-migrate'}
        Then it says {'msg-7.json (reviewer) delivered by a person despite the filter'}
        And it does not say {'msg-8.json'}
        And it says {'the machine does not stream what came before'}

    # One arriving from an external peer is held on its way in, before any task has seen it, so the
    # list says which way each message was going.
    Scenario: a held message says which way it was going
        Given a backend with work on it
        And {'porelo-checkout-shell'} has a message held for {'reviewer'} saying {'please look at the diff'}
        And {'porelo-checkout-shell'} has a message held coming in from {'partner'} saying {'here is the file'}
        And the app is running
        And I go to what needs a person
        Then it says {'going out from porelo-checkout-shell to reviewer'}
        And it says {'coming in from partner to porelo-checkout-shell'}
        # Walk 10: one held on its way in was taken for the one sent. What is decided is only the task's copy.
        And it says {'Whoever wrote it has sent it already; it only waits to reach porelo-checkout-shell.'}
        And it says {'Read it, and decide whether porelo-checkout-shell gets it'}

    # Absent is not zero: a daemon that does not count says nothing about what was used.
    # Whether anything to that peer is held right now, read from what the machine lists as waiting.
    Scenario: a peer says how many messages with it wait for a person now
        Given a backend with work on it
        And {'porelo-checkout-migrate'} may talk to {'reviewer'}, {'vouched'}, in {'prompt'}
        And {'porelo-checkout-migrate'} has a message held for {'reviewer'} saying {'first'}
        And {'porelo-checkout-migrate'} has a message held for {'reviewer'} saying {'second'}
        And the app is running
        When I choose {"Hold its project's messages to a peer"} from the menu of the tile {'porelo-checkout-migrate'}
        Then it says {'2 messages with it wait for a person now'}

    # Filtered here per task and per project: the stream covers every mailbox on the machine.
    Scenario: what happened is followed for the whole project on request, and never another project's
        Given a backend with work on it
        And {'porelo-checkout-migrate'} may talk to {'reviewer'}, {'vouched'}, in {'prompt'}
        And the app is running
        When the machine says {'msg-7.json'} of {'porelo-checkout-migrate'} was {'held'}
        And the machine says {'msg-8.json'} of {'porelo-checkout-shell'} was {'sent'}
        And the machine says {'msg-9.json'} of {'porelo-billing-shell'} was {'sent'}
        And I choose {"Hold its project's messages to a peer"} from the menu of the tile {'porelo-checkout-migrate'}
        Then it says {'msg-7.json'}
        And it does not say {'msg-8.json'}
        When I follow what happens for the whole project
        Then it says {'msg-8.json'}
        And it does not say {'msg-9.json'}

    # One held on its way in is released to the task it was for, never back out.
    Scenario: releasing a message held on its way in says it reaches the task
        Given a backend with work on it
        And {'porelo-checkout-shell'} has a message held coming in from {'partner'} saying {'here is the review'}
        And the app is running
        And I go to what needs a person
        When I read the message from {'porelo-checkout-shell'}
        And I release the message
        Then it says {'Released. The next pass checks it again, as every arrival is checked'}
        And it says {'one held for its signature is held again'}
        And it does not say {'goes out'}

    # A person's release goes whatever a hold says: the switch says so.
    Scenario: holding everything for a peer says a person's release still goes
        Given a backend with work on it
        And {'porelo-checkout-migrate'} may talk to {'reviewer'}, {'vouched'}, in {'prompt'}
        And the app is running
        When I choose {"Hold its project's messages to a peer"} from the menu of the tile {'porelo-checkout-migrate'}
        Then it says {'Nothing goes to it unless a person releases it, or until this is off again'}
