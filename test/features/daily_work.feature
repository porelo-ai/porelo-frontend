# The Feature line is the report row: one short sentence, 70 characters at most,
# saying what this file tests. It is the group name in every surface CI renders.
Feature: Daily work in front, setting up machines and projects apart

    # Decided: machines (where work runs) and projects (how it runs) are set up
    # rarely; the daily view is the work, what needs a person, and starting new work.
    Background:
        Given a backend with work on it
        And the app is running

    Scenario: the window opens on the work of every machine, what waits for a person first
        Then the section shown is {'Work'}
        And the work {'porelo-checkout-migrate'} is in the group {'waiting'}
        And the work {'porelo-checkout-shell'} is in the group {'running'}
        And the work {'porelo-billing-shell'} is in the group {'running'}

    # Walk 9: stopped work is rarely what a person looks for, so its group starts shut.
    Scenario: stopped work is shown apart, its group shut until opened
        Given the work {'porelo-billing-shell'} has stopped
        Then the group {'stopped'} is shut {true}
        When I open the group {'stopped'}
        Then the work {'porelo-billing-shell'} is in the group {'stopped'}

    # Walk 9: a tile is its work, its machine and its mark; the rest when opened.
    Scenario: a tile on the work page is folded to its work and machine, and opened for the rest
        Then the tile {'porelo-billing-shell'} is folded {true}
        When I open the tile {'porelo-billing-shell'}
        Then the tile {'porelo-billing-shell'} is folded {false}

    Scenario: a tile that asks something of a person is never folded
        Then the tile {'porelo-checkout-migrate'} is folded {false}

    # Walk 9: within each group, the work active last comes first.
    Scenario: the work in a group is in the order of its last activity, newest first
        Given the work {'porelo-billing-shell'} has been in its state since {'2026-10-03T08:00:00Z'}
        And the work {'porelo-checkout-shell'} has been in its state since {'2026-10-01T08:00:00Z'}
        Then the work {'porelo-billing-shell'} comes before {'porelo-checkout-shell'}

    Scenario: the work is narrowed to one project, and widened back
        When I narrow the work to the project {'billing'}
        Then no tile is shown for {'porelo-checkout-shell'}
        And the work {'porelo-billing-shell'} is in the group {'running'}
        When I narrow the work to every project
        Then the work {'porelo-checkout-shell'} is in the group {'running'}

    Scenario: new work asks in which project, and opens the start for it
        When I start new work
        And I choose the project {'billing'} for it
        Then it says {'Start work in billing'}

    Scenario: new work can be in no project
        When I start new work
        And I choose no project for it
        Then it says {'Start work without a project'}

    Scenario: machines are a page of setting up, each with its projects under it
        When I go to the place {'machines'}
        Then the section shown is {'Machines'}
        And the project {'checkout'} is listed
        And the project {'billing'} is listed

    Scenario: projects are a page of setting up, each opened on its machine
        When I go to the place {'projects'}
        Then the projects page lists {'checkout'} on {'this machine'}
        When I open {'billing'} on {'this machine'} from the projects page
        Then the project {'billing'} is the one shown

    # work of one project on two machines cannot share its conversation through each
    # machine's own homeserver, and a person starting it there is told before, not after.
    Scenario: starting work of a project that runs on another machine says they cannot talk
        Given the project {'checkout'} has a conversation over {'matrix'} reaching {'127.0.0.1:8008'}, ready
        And the machine {'elsewhere'} runs work of {'checkout'}
        When I start new work on {'this machine'} in {'checkout'}
        Then it says {'Work of checkout runs on elsewhere already'}
        And it says {'only through a central Matrix server, and this project names none'}

    Scenario: a project on a central server is said not to be joined by a second machine yet
        Given the project {'checkout'} has a conversation over {'matrix'} reaching {'https://matrix.example.org'}, ready
        And the machine {'elsewhere'} runs work of {'checkout'}
        When I start new work on {'this machine'} in {'checkout'}
        Then it says {'a second machine cannot join it yet'}

    Scenario: a project without a conversation says nothing about another machine
        Given the machine {'elsewhere'} runs work of {'checkout'}
        When I start new work on {'this machine'} in {'checkout'}
        Then it does not say {'runs on elsewhere already'}

    # What a tile's action answered was said only on the machine's page, and from the work page an
    # action seemed to do nothing (found running the leased machine's leg against the new window).
    Scenario: what an action from a tile answers is said on the work page
        When I choose {'Write to its agent'} from the menu of the tile {'porelo-checkout-migrate'}
        And I put {'the schema changed'} in its inbox
        Then the section shown is {'Work'}
        And the status line mentions {'Written into the inbox of porelo-checkout-migrate'}

    Scenario: the order follows the last activity, whichever work it was
        Given the work {'porelo-checkout-shell'} has been in its state since {'2026-10-03T08:00:00Z'}
        And the work {'porelo-billing-shell'} has been in its state since {'2026-10-01T08:00:00Z'}
        Then the work {'porelo-checkout-shell'} comes before {'porelo-billing-shell'}

    # Walk 9: "Stopped (10)" stayed at 10 after one was removed.
    Scenario: removing stopped work counts it out of its group
        Given the work {'porelo-billing-shell'} has stopped
        And the work {'porelo-billing-audit'} has stopped
        When I open the group {'stopped'}
        Then it says {'Stopped (2)'}
        When I choose {'Remove it'} from the menu of the tile {'porelo-billing-shell'}
        And I press {'Remove it'}
        Then it says {'Stopped (1)'}

    # Walk 9: a removal the machine refused was said only in the status line of the
    # work page, and "nothing happens" was what was seen.
    Scenario: a removal the machine refuses is put in front of the person on the work page
        Given the work {'porelo-billing-shell'} has stopped
        And removing will refuse because the work is held
        When I open the group {'stopped'}
        And I choose {'Remove it'} from the menu of the tile {'porelo-billing-shell'}
        And I press {'Remove it'}
        Then what is held is shown
        # Walk 9: the group that had been opened was shut again once the refusal was decided.
        When I choose {'Leave it alone'}
        Then the group {'stopped'} is shut {false}

    # Walk 9: Machines is a list of machines, each with details of its own; its projects
    # are under Projects and its work under Work, never on a machine's or a project's page.
    Scenario: machines are a list, and a machine's details show no projects and no work
        Then the machines page lists only machines
        When I open the details of {'this machine'}
        Then the title is {'this machine'}
        And no work is shown on this page

    Scenario: a project's page shows no work, and leads to its work on the work page
        When I select the project {'billing'}
        Then the title is {'this machine › billing'}
        And no work is shown on this page
        When I go to its work
        Then the section shown is {'Work'}
        And no tile is shown for {'porelo-checkout-shell'}
        And the work {'porelo-billing-shell'} is in the group {'running'}

    # Walk 9: removing a machine from the list sent the window to Needs you.
    Scenario: removing a machine from the list stays on the list
        When I watch another machine called {'elsewhere'}
        And I remove {'elsewhere'} from the list of machines
        Then the section shown is {'Machines'}
        And the machine {'elsewhere'} is listed {false}

    Scenario: a project's page whose project went goes back to the list of projects
        When I select the project {'billing'}
        And the machine no longer has the project {'billing'}
        Then the section shown is {'Projects'}

    # Walk 9: this computer itself is never removed from the list.
    Scenario: this computer cannot be removed from the list of machines, another can
        When I watch another machine called {'elsewhere'}
        Then the machine {'this machine'} can be removed from the list {false}
        And the machine {'elsewhere'} can be removed from the list {true}

    # Walk 9: a project's commands are on its row, as a tile's are on the tile.
    Scenario: a project's row carries its menu, and its page the points to change it
        When I go to the place {'projects'}
        And I choose {'Stop telling me about this project'} from the menu of the project {'checkout'}
        Then the project {'checkout'} is marked as silent
        When I select the project {'checkout'}
        Then the project's page offers {'Show what this project would open, creating nothing'}
        And the project's page offers {'What this project may reach'}

    Scenario: a project's page shows the project, not a bar of its machine
        When I select the project {'billing'}
        Then the machine's bar is shown {false}
        When I open the details of {'this machine'}
        Then the machine's bar is shown {true}

    # Walk 9: Projects is the view of what projects there are. A project is one, on however
    # many machines, and so is Default; its page chooses which machine it shows.
    Scenario: a project on two machines is listed once, saying both, and its page chooses between them
        Given the machine {'elsewhere'} runs work of {'checkout'}
        When I go to the place {'projects'}
        Then the card of {'checkout'} lists the machines {'this machine, elsewhere'}
        When I open {'checkout'} on {'elsewhere'} from the projects page
        Then the title is {'elsewhere › checkout'}
