# The Feature line is the report row: one short sentence, 70 characters at most,
# saying what this file tests. Run by tool/play_story.sh through tool/walk_idea.sh against a local VM, never in the Build.
Feature: A task's results land where the next step and others find them

    # The idea walk up to its reading, with a seed whose tests hold a fault the reader is bound to find and whose builder
    # is asked to bring back one idea of its own. A reader's findings are the Findings block its answer ends with: the
    # planner judges them and keeps them in its own work record, where the window shows them; nothing goes into Git.
    Scenario: a reading's findings stop it, are worked off by a rework, and an idea becomes an issue
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
        And the planner shows the reading's blocking findings and Needs you lists the issue
        When I choose Rework for the stopped reading
        And the window starts the offered rework task and it ends
        Then the planner shows the findings worked off
