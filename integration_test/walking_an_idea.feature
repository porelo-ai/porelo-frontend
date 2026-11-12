# The Feature line is the report row: one short sentence, 70 characters at most,
# saying what this file tests. Run by tool/walk_idea.sh against a local VM, never in the Build.
Feature: A real idea walks to Finished through the window

    # The window runs in a VM against that VM's own porelo and the planner the driver put first on
    # its path, as the test person. Each read step asks the planner's probe and porelo on the machine,
    # never the window, and the walk stops at the first step whose effect does not appear.
    Scenario: an idea made in a discussion is taken to Finished
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
        Then the story stands in Review
        When I set the story Finished
        Then the story stands in Finished and porelo holds its records
