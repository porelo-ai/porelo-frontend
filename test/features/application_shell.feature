# The Feature line is the report row: one short sentence, 70 characters at most,
# saying what this file tests. It is the group name in every surface CI renders.
Feature: Moving around the frame by keyboard and by pointer

    Background:
        Given a backend with work on it
        And the app is running
        And I go to the work

    Scenario: what is on the machine is answered before anything is selected
        Then the project {'checkout'} is listed
        And the project {'billing'} is listed
        And the status line mentions {'Connected'}

    Scenario: a project and its work are each one selection away
        When I select the project {'checkout'}
        Then the work {'porelo-checkout-shell'} is listed
        When I select the work {'porelo-checkout-shell'}
        And I open the selection
        Then the detail for {'porelo-checkout-shell'} is shown

    Scenario: the frame is worked from the keyboard with no pointer at all
        When I move the keyboard to the project {'billing'}
        And I press enter
        Then the project {'billing'} is selected

    Scenario: closing a detail comes back with the same selection still made
        When I select the project {'checkout'}
        And I select the work {'porelo-checkout-shell'}
        And I open the selection
        And I close what is open
        Then the work pane is shown
        And the work {'porelo-checkout-shell'} is still selected
        And the project {'checkout'} is selected

    Scenario: one finder names actions belonging to a screen that is not open
        When I open the command finder
        Then the command finder names {'Refresh from the backend'}
        And the command finder names {'Open the selected work'}
        And the command {'Open the selected work'} is offered as unavailable

    Scenario: every action is reachable with a pointer alone
        When I open the menu {'Options'}
        And I choose the menu entry {'Appearance: dark'}
        Then the appearance is {'dark'}

    Scenario: the status line says in words what the last action did
        When I choose the command {'Refresh from the backend'}
        Then the status line mentions {'Refreshed'}

    Scenario: appearance is a choice and it survives a restart
        When I choose the command {'Appearance: dark'}
        Then the appearance is {'dark'}
        When the app is restarted
        Then the appearance is {'dark'}

    Scenario: a narrow window keeps the rail behind the menu button
        When the window is {420} pixels wide
        Then the rail is shown {false}
        When I open the machines
        Then the rail is shown {true}

    # The finder teaches where things are: it goes there and marks the action, rather than running it
    # from nowhere.
    Scenario: the finder goes to where an action lives and marks it there
        When I open the command finder
        And I pick {'Check whether this machine can run anything'} in the finder
        Then the menu that holds {'Check whether this machine can run anything'} is open with it marked

    Scenario: the title bar holds only what belongs to no machine
        Then the title bar offers {'Find a command (Ctrl+K), Watch another machine…, Options, About Porelo'}

    Scenario: the title says where you are
        Then the title is {'this machine'}
        When I select the project {'checkout'}
        Then the title is {'this machine › checkout'}
        When I go to the place {'work'}
        Then the title is {'Work'}

    # A machine that does not answer cannot be asked anything, so nothing that would ask it is offered.
    Scenario: a machine that does not answer offers nothing that needs it, and says why
        When I select the project {'checkout'}
        And the tunnel drops
        And I open the command finder
        Then the command {'Follow a project'} is unavailable because {'not answering'}
        And the command {'Build the environment for this project'} is unavailable because {'not answering'}
        When I close what is open
        And enough time passes for another try

    # The check is asked of the daemon, and is most wanted when none answers: where this interface can
    # start Porelo, the check offers that first, and checks once it answers.
    Scenario: checking a machine that does not answer offers to start Porelo there first
        Given nothing answers on that machine
        When the tunnel drops
        And I choose the command {'Check whether this machine can run anything'}
        Then it says {'Start Porelo on this computer?'}
        And it says {'This starts the daemon here, as you.'}
        When I agree to start it
        Then the machine was asked to start {'systemctl --user'}
        And it says {'What this machine can run'}

    Scenario: following a repository and the stop for every machine wait for a machine that answers
        When the tunnel drops
        Then following a repository on this machine is not offered
        And stopping everything everywhere is not offered
        When enough time passes for another try
        Then stopping everything everywhere is offered
