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
