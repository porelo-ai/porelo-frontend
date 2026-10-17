# The Feature line is the report row: one short sentence, 70 characters at most,
# saying what this file tests. It is the group name in every surface CI renders.
Feature: The services a credential can be for, managed from here

    Background:
        Given a backend with work on it
        And the app is running
        And I go to the work

    Scenario: the machine's menu opens its destinations
        When I open the menu {'What this machine can be told to do'}
        Then the menu offers {'Destinations — the services a credential can be for'}
        When I choose the menu entry {'Destinations — the services a credential can be for'}
        Then the destinations of the machine are open

    # Where requests go and where the key goes in them: what a person needs to tell two apart.
    Scenario: each destination says where it is and where its key goes
        Given the machine declares the destination {'weather'} at {'https://api.weather.example/v1'}
        When I choose the command {'Destinations — the services a credential can be for'}
        Then it says {'https://api.weather.example/v1'}
        And it says {'The key goes in the header Authorization, after "Bearer ".'}

    # Nothing is written that the machine did not read back first, exactly as it was typed.
    Scenario: a destination is checked by the machine before it is written
        When I choose the command {'Destinations — the services a credential can be for'}
        And I add the destination {'weather'} at {'https://api.weather.example/v1'}
        Then the destination cannot be written yet
        When I check the destination
        Then it says {'The machine would read it back as https://api.weather.example/v1'}
        And nothing was written to the machine
        When I write the destination
        Then the machine wrote the destination {'weather'}
        And it says {'Written: weather'}

    # What is written is what was checked: typing after the check asks for another.
    Scenario: a destination changed after its check is checked again before it is written
        When I choose the command {'Destinations — the services a credential can be for'}
        And I add the destination {'weather'} at {'https://api.weather.example/v1'}
        And I check the destination
        And I type the destination's address {'https://api.weather.example/v2'}
        Then the destination cannot be written yet

    Scenario: a destination the machine refuses is said in its words, and nothing is written
        When I choose the command {'Destinations — the services a credential can be for'}
        And I add the destination {'weather'} at {'http://api.weather.example'}
        And I check the destination
        Then it says {'must be reached over https'}
        And the destination cannot be written yet
        And nothing was written to the machine

    Scenario: a destination of one's own is removed, and the file it was is named
        Given the machine declares the destination {'weather'} at {'https://api.weather.example/v1'}
        When I choose the command {'Destinations — the services a credential can be for'}
        And I remove the destination {'weather'}
        Then it says {'Removed weather'}
        And it says {'No destination is declared on this machine.'}

    # A package's file is the package's; one of the person's own can only take its place.
    Scenario: a destination a package installed is not removed or changed here
        Given a package declares the destination {'search'} at {'https://api.search.example'}
        When I choose the command {'Destinations — the services a credential can be for'}
        Then the destination {'search'} offers no removal
        And it says {'Put your own in its place'}

    Scenario: one's own destination put in the place of a package's says the package's is not in force
        Given a package declares the destination {'search'} at {'https://api.search.example'}
        When I choose the command {'Destinations — the services a credential can be for'}
        And I put my own in the place of {'search'} at {'https://search.internal.example'}
        Then it says {'Installed by a package, and not in force'}
