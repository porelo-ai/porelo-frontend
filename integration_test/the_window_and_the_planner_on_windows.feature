# The Feature line is the report row: one short sentence, 70 characters at most,
# saying what this file tests. Run by tool/play_story.sh on a Windows test machine, never in the Build.
Feature: The window and the planner on Windows

    # The window runs in the desktop session of the Windows machine, beside porelo-planner as its package put it
    # there; the driver installs both before and reads both Windows builds after. What a step reads of the planner it
    # reads on the machine: its address file and its process, never the window's word for it.
    Scenario: Planning shows the board, read through the planner on this computer
        Given the interface is running
        When I open Planning
        Then the board appears, read through the planner on this computer
        And no note says planning is not offered
