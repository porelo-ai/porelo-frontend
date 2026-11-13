# The Feature line is the report row: one short sentence, 70 characters at most,
# saying what this file tests. Run by tool/play_story.sh through tool/walk_idea.sh against a local VM, never in the Build.
Feature: The planner moves work on from state to state by itself

    # The idea walk with two issue repositories, up to the end of its builders, on a seed whose second repository holds
    # a fault its reader blocks on. From there nothing is started by a step: what moves, the planner and the window
    # move, and a step reads it on the board, in porelo and in the window; only where a reading stops on its blocking
    # findings does the person choose, Rework, on its Needs-you entry. Last, a task fails on a key its provider
    # refuses, and its card is read.
    Scenario: work ends, is read and moves on by itself, and a stopped reading is reworked on a choice
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
        Then Reading is set and its reader runs with no dialog shown
        When the readers end
        Then the first issue stands in Review
        And the second's reading stops on its blocking findings and Needs you lists it
        When I choose Rework on its Needs-you entry
        Then the window runs the rework and it ends
        When a task fails on a key its provider refuses
        Then the failed task's card stays, with a warning and a Needs-you entry to its result
