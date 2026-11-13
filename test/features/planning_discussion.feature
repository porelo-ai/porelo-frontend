Feature: Discuss an idea with an agent from the planning board

    Background:
        Given a backend with planning
        And the app is running
        When I open the planning board

    # Harm: a discussion starts with an agent the person never chose, or as an ordinary task that may push.
    Scenario: The person picks the agent and the discussion reads every repository, read only
        When I offer the idea {'Let the board show who is at work'} for discussion
        Then the discussion's Start says {'every repository of the project, read only'}
        When I start the discussion with the agent {'other-agent'}
        Then the machine starts a discussion over every repository with the agent {'other-agent'}

    # Harm: a discussion the person turned away starts all the same.
    Scenario: Turning the discussion's Start away starts nothing
        When I offer the idea {'Let the board show who is at work'} for discussion
        And I turn the discussion's Start away
        Then no discussion is started

    # Harm: a discussion starts and the person is never shown its session, so nobody leads the talk.
    Scenario: A started discussion opens its session
        When I offer the idea {'Let the board show who is at work'} for discussion
        And I start the discussion with the agent {'other-agent'}
        Then the discussion's session is on screen

    # Harm: a discussion the machine refuses seems to do nothing: the log says nothing, and no notice shows its words.
    Scenario: A discussion Start the machine refuses is said in the log and in a notice
        Given the window's log is kept
        And the machine refuses the discussion's Start with exit {78}, saying {'porelo: no-homeserver: porelo names no homeserver'}
        When I offer the idea {'Let the board show who is at work'} for discussion
        And I start the discussion with the agent {'other-agent'}
        Then the window's log says {'Start of a discussion for checkout on this machine was refused'}
        And the window's log says {'porelo: no-homeserver: porelo names no homeserver'}
        And the notice of the refused Start says {'porelo: no-homeserver: porelo names no homeserver'}

    # Harm: a discussion the person turned away is logged and noticed as the machine's refusal.
    Scenario: A discussion Start turned away is neither logged as refused nor noticed
        Given the window's log is kept
        When I offer the idea {'Let the board show who is at work'} for discussion
        And I turn the discussion's Start away
        Then the window's log says nothing of {'was refused'}
        And no notice says a Start was refused
