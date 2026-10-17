# The Feature line is the report row: one short sentence, 70 characters at most,
# saying what this file tests. It is the group name in every surface CI renders.
Feature: Building a project's environment, and watching it run

    Background:
        Given a backend with work on it
        And the app is running
        And I go to the work
        And I select the project {'checkout'}

    # Nothing is started: this builds the image a task would otherwise build on its way to running,
    # which is where the first task in a project spends its minutes.
    Scenario: an environment is built without starting anything
        When I build the environment for this project
        And I choose to build {'what changed'}
        Then the build asked for {'CACHED'}
        And nothing was started

    # The depth is what the build costs, and it is asked before the build rather than warned about
    # afterwards. Three, because three are real: the middle one keeps the base image and its
    # packages, and works by invalidating the cache where the agent's layers begin.
    Scenario: the depths say what each replaces and roughly what it costs
        When I build the environment for this project
        Then it says {'Keeps the base image and the packages on it'}
        And it says {'Roughly a minute or two.'}
        And it says {'Throws away the packages on the base image as well'}
        And it says {'Roughly several minutes, and it downloads.'}

    Scenario: the deepest rebuild is asked for as itself
        When I build the environment for this project
        And I choose to build {'everything'}
        Then the build asked for {'EVERYTHING'}

    Scenario: progress is visible while it runs, and the frame stays usable
        When I build the environment for this project
        And I choose to build {'what changed'}
        Then the operation shows {'STEP 4/6: RUN apt-get install -y git'}
        When I close what is open
        Then the project {'checkout'} is listed

    # A build fails at a line of a Containerfile, and the one thing somebody needs is which line.
    Scenario: a build that fails names the step, and it is still readable afterwards
        Given the next build will fail
        When I build the environment for this project
        And I choose to build {'what changed'}
        Then it says {'STEP 4/6: RUN apt-get install -y git returned 100'}
        When I show what this session has run
        Then the record marks it as failed

    # `Prepare` takes the project file, so a project nothing recorded one for cannot be prepared —
    # unlike removing what was built, which takes the name.
    Scenario: a project whose file nothing can find says why it cannot be built
        When I select the project {'unrecorded'}
        And I open the command finder
        Then the command {'Build the environment for this project'} is offered as unavailable
