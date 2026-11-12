# The Feature line is the report row: one short sentence, 70 characters at most,
# saying what this file tests. Run by tool/walk_idea.sh --test forwarding_to_a_branch against a local VM, never in
# the Build.
Feature: Approved work forwarded to a chosen branch lands on it at GitHub

    # The window runs in a VM against that VM's own porelo, as the test person, with the forge's token of the run.
    # A task there pushes to its gate; the person reviews it and forwards it upstream. GitHub's own answer, read with
    # git, is what each scenario compares the reviewed commit with.
    Scenario: work forwarded onto a branch the repository has lands on that branch
        Given the interface is running
        And a task in the forwarding repository has work waiting at its gate
        When I review that work at the gate
        And I forward it upstream onto the branch the repository has
        Then GitHub has that branch at the reviewed commit and the default branch where it was

    Scenario: work forwarded onto a branch the person types lands on that new branch
        Given the interface is running
        And a task in the forwarding repository has work waiting at its gate
        When I review that work at the gate
        And I forward it upstream onto a new branch I type
        Then GitHub has that branch at the reviewed commit and the default branch where it was
