# The Feature line is the report row: one short sentence, 70 characters at most,
# saying what this file tests. It is the group name in every surface CI renders.
Feature: Naming a job so it can be started again

    Background:
        Given a backend with work on it
        And the app is running
        And I go to the work
        And I select the project {'checkout'}

    Scenario: a job is named, and becomes an action of its own
        When I start work in this project
        And I choose the agent {'An Agent'}
        And I choose {'Unattended, against a prompt'}
        And I ask it to {'Run the nightly tests'}
        And I keep it as {'nightly-tests'}
        And I leave without starting
        And I open the command finder
        Then the command finder names {'Run nightly-tests in checkout'}

    Scenario: starting from a named job is one action, and it runs what the job carried
        Given the job {'nightly-tests'} is already named
        When I choose the command {'Run nightly-tests in checkout'}
        And I start it
        Then the launch asked for the mode {'UNATTENDED'}
        And the launch asked it to {'Run the nightly tests'}

    Scenario: what the job asks for is editable before it runs
        Given the job {'nightly-tests'} is already named
        When I choose the command {'Run nightly-tests in checkout'}
        Then what to ask it says {'Run the nightly tests'}
        When I ask it to {'Run the nightly tests, and the slow ones too'}
        And I start it
        Then the launch asked it to {'Run the nightly tests, and the slow ones too'}

    Scenario: a job named in one project is not offered in another
        Given the job {'nightly-tests'} is already named
        When I select the project {'billing'}
        And I open the command finder
        Then the command finder does not name {'Run nightly-tests in checkout'}

    Scenario: a named job outlives the run that named it
        Given the job {'nightly-tests'} is already named
        When the app is restarted
        And I go to the work
        And I select the project {'checkout'}
        And I open the command finder
        Then the command finder names {'Run nightly-tests in checkout'}

    # Every start names a repository, so a job keeps the one it was named with.
    Scenario: a job keeps the repository it was named with, and starts there
        Given the project {'checkout'} has the repositories {'checkout, payments-api'}
        When I start work in this project
        And I choose the agent {'An Agent'}
        And I choose {'Unattended, against a prompt'}
        And I choose the repository {'payments-api'}
        And I ask it to {'Run the nightly tests'}
        And I keep it as {'nightly-tests'}
        And I leave without starting
        And I choose the command {'Run nightly-tests in checkout'}
        Then the repository {'payments-api'} is chosen
        When I start it
        Then the launch was in the repository {'payments-api'}

    Scenario: a job named without a repository has one chosen when it starts, not for it
        Given the job {'nightly-tests'} is already named
        And the project {'checkout'} has the repositories {'checkout, payments-api, billing'}
        When I choose the command {'Run nightly-tests in checkout'}
        Then no repository is chosen yet

