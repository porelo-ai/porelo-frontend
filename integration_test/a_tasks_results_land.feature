# The Feature line is the report row: one short sentence, 70 characters at most,
# saying what this file tests. Run by tool/play_story.sh through tool/walk_idea.sh against a local VM, never in the Build.
Feature: A task's results land where the next step and others find them

    # The idea walk up to its reading, with a seed whose work the reader is bound to find fault with and whose
    # instructions ask a task to bring back one idea of its own. What a step reads after the reading, it reads in fresh
    # clones of the forge's repositories, made apart from everything the window and its tasks use and removed again.
    Scenario: a reading's findings are kept, worked off by a rework, and an idea becomes an issue
        Given the interface is running
        When I open the planning of the walk project
        Then the planner from the path answers for the project
        When I discuss an idea with the walk agent until the discussion ends
        Then porelo on the machine says the discussion ran and ended
        When the window hands the idea in
        Then the planner holds the story with its issues in Idea
        When I move each issue of the story to Backlog one state at a time
        Then each issue stands in Backlog on the board and in its file
        When I ask for the work of the story to Implementing with the walk agent
        Then the proposal moved nothing
        When I order the work and start its builder task
        Then the builder task runs and the story stands in Implementing
        When the builder agent works until its task ends
        Then the forge holds the work of the builder agent
        When the window posts the end of the builder task
        Then each issue is in Reading for a reader
        When the window starts the offered reader task and it ends
        Then the idea a task brought back is an issue in Idea
        And the findings file lies where the project's setting says
        When the window starts the offered rework task and it ends
        Then the findings are worked off and the file is deleted
        And a fresh clone shows the findings commit and its deletion
