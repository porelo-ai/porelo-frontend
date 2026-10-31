# The Feature line is the report row: one short sentence, 70 characters at most,
# saying what this file tests. It is the group name in every surface CI renders.
Feature: Raising and dropping the forward that reaches a machine

    Background:
        Given a backend with work on it
        And the app is running
        And I go to the work

    Scenario: a machine is described by where it is, and the forward is raised here
        When I start watching another machine
        And I choose {'Raise the forward for me'}
        And I say it is called {'the build machine'}
        And I say it is at {'user@build.example.test'}
        And its socket there is {'/run/user/1001/porelo/porelod.sock'}
        And I watch it
        Then the forward was raised for {'the build machine'}
        And the machine {'the build machine'} says the forward is raised here

    Scenario: how it is reached is chosen, never assumed
        When I open the machine dialog
        And I say it is called {'the build machine'}
        Then watching it is not offered yet

    Scenario: a machine whose socket is already forwarded has nothing raised for it
        When I watch another machine called {'elsewhere'}
        Then nothing was raised for {'elsewhere'}
        And the machine {'elsewhere'} does not say the forward is raised here

    Scenario: a forward that cannot be raised says what the transport said
        Given raising a forward will fail with {'Host key verification failed.'}
        When I start watching another machine
        And I choose {'Raise the forward for me'}
        And I say it is called {'the build machine'}
        And I say it is at {'user@build.example.test'}
        And its socket there is {'/run/user/1001/porelo/porelod.sock'}
        And I watch it
        Then the machine {'the build machine'} says {'This computer does not know user@build.example.test’s host key yet, or it changed.'}

    # A machine that answered yesterday and does not today is usually a daemon nobody started.
    Scenario: a watched machine that is silent can be started from its menu, once somebody agrees
        Given nothing answers on that machine
        When I start watching another machine
        And I choose {'Raise the forward for me'}
        And I say it is called {'the build machine'}
        And I say it is at {'user@build.example.test'}
        And its socket there is {'/run/user/1001/porelo/porelod.sock'}
        And I watch it
        And I switch to the machine {'the build machine'}
        And I ask to start Porelo on this machine
        Then nothing was started on that machine
        When I agree to start it
        Then the machine was asked to start {'setsid porelod'}
        And the session recorded {'Start Porelo on user@build.example.test'}
        And the machine {'the build machine'} answers again

    Scenario: a start nobody agreed to runs nothing
        Given nothing answers on that machine
        When I start watching another machine
        And I choose {'Raise the forward for me'}
        And I say it is called {'the build machine'}
        And I say it is at {'user@build.example.test'}
        And its socket there is {'/run/user/1001/porelo/porelod.sock'}
        And I watch it
        And I switch to the machine {'the build machine'}
        And I ask to start Porelo on this machine
        And I do not agree to start it
        Then nothing was started on that machine
        When the machine can answer again
        Then the machine {'the build machine'} answers again

    Scenario: a machine that answers is offered no start at all
        When I start watching another machine
        And I choose {'Raise the forward for me'}
        And I say it is called {'the build machine'}
        And I say it is at {'user@build.example.test'}
        And its socket there is {'/run/user/1001/porelo/porelod.sock'}
        And I watch it
        And I switch to the machine {'the build machine'}
        And I open the command finder
        Then the command {'Start Porelo on this machine'} is unavailable because {'already answering'}

    Scenario: a machine somebody else forwards is offered no start, because there is no host
        When I watch another machine called {'elsewhere'}
        And I switch to the machine {'elsewhere'}
        And I open the command finder
        Then the command {'Start Porelo on this machine'} is unavailable because {'somebody else'}

    # Stopping is the other half of starting: a console can do it, so the interface can too. Since the
    # tasks run on without their daemon, what it costs is the watching and the questions nobody answers.
    Scenario: a machine that answers can be stopped from its menu, told first what stopping costs
        When I start watching another machine
        And I choose {'Raise the forward for me'}
        And I say it is called {'the build machine'}
        And I say it is at {'user@build.example.test'}
        And its socket there is {'/run/user/1001/porelo/porelod.sock'}
        And I watch it
        And I switch to the machine {'the build machine'}
        And I ask to stop Porelo on this machine
        Then it says {'What runs there goes on running'}
        And it says {'nothing here watches it'}
        And it says {'goes unanswered and runs out'}
        And nothing was stopped on that machine
        When I agree to stop it
        Then the machine was asked to stop {'systemctl --user stop porelod'}
        And the session recorded {'Stop Porelo on user@build.example.test'}
        And the machine {'the build machine'} no longer answers
        When I open the command finder
        Then the command {'Start Porelo on this machine'} is offered
        When the machine can answer again
        Then the machine {'the build machine'} answers again

    Scenario: a stop nobody agreed to runs nothing
        When I start watching another machine
        And I choose {'Raise the forward for me'}
        And I say it is called {'the build machine'}
        And I say it is at {'user@build.example.test'}
        And its socket there is {'/run/user/1001/porelo/porelod.sock'}
        And I watch it
        And I switch to the machine {'the build machine'}
        And I ask to stop Porelo on this machine
        And I do not agree to stop it
        Then nothing was stopped on that machine
        And the machine {'the build machine'} answers again

    Scenario: a machine that is not answering is offered no stop
        Given nothing answers on that machine
        When I start watching another machine
        And I choose {'Raise the forward for me'}
        And I say it is called {'the build machine'}
        And I say it is at {'user@build.example.test'}
        And its socket there is {'/run/user/1001/porelo/porelod.sock'}
        And I watch it
        And I switch to the machine {'the build machine'}
        And I open the command finder
        Then the command {'Stop Porelo on this machine'} is unavailable because {'not answering'}
        When the machine can answer again
        Then the machine {'the build machine'} answers again

    Scenario: a machine somebody else forwards is offered no stop, because there is no host
        When I watch another machine called {'elsewhere'}
        And I switch to the machine {'elsewhere'}
        And I open the command finder
        Then the command {'Stop Porelo on this machine'} is unavailable because {'somebody else'}

    Scenario: closing the interface leaves no forward it raised still running
        When I start watching another machine
        And I choose {'Raise the forward for me'}
        And I say it is called {'the build machine'}
        And I say it is at {'user@build.example.test'}
        And its socket there is {'/run/user/1001/porelo/porelod.sock'}
        And I watch it
        And I close the interface
        Then no forward this interface raised is still running

    Scenario: a forward the interface did not raise is never torn down by it
        When I watch another machine called {'elsewhere'}
        And I close the interface
        Then nothing was torn down for {'elsewhere'}

    Scenario: the socket on the other machine is asked for, never guessed
        When I start watching another machine
        And I choose {'Raise the forward for me'}
        Then its socket there is not filled in

    # A person new to Porelo knows how they log in, not a uid: left empty, the machine is asked.
    Scenario: a socket left empty is asked of the machine when it is watched, and the forward goes there
        Given the account logs in as uid {1007}
        When I start watching another machine
        And I choose {'Raise the forward for me'}
        And I say it is called {'the build machine'}
        And I say it is at {'user@build.example.test'}
        And I watch it
        Then the machine was asked who {'user@build.example.test'} logs in as
        And the forward was raised through {'user@build.example.test'} to {'/run/user/1007/porelo/porelod.sock'}

    # What setting a machine up wrote on this computer is offered for removal when it is forgotten, and
    # only offered: the Host entry in exactly the form the wizard writes. A machine has no key of its own
    # any more; the person's one key stays.
    Scenario: forgetting a machine the wizard set up offers its Host entry, and removes it not unasked
        Given the wizard set up the machine {'build'}
        And I switch to the machine {'build'}
        When I ask to forget this machine
        Then it says {'Also remove Host porelo-build from ~/.ssh/config'}
        When I forget it
        Then the ssh config still has the Host {'porelo-build'}

    Scenario: forgetting a machine the wizard set up removes its Host entry when asked
        Given the wizard set up the machine {'build'}
        And I switch to the machine {'build'}
        When I ask to forget this machine
        And I also remove its Host entry
        And I forget it
        Then the ssh config no longer has the Host {'porelo-build'}
        And the ssh config as it was before is kept

    Scenario: a Host entry written by hand is never offered for removal
        Given the machine {'handmade'} is reached through a Host entry written by hand
        And I switch to the machine {'handmade'}
        When I ask to forget this machine
        And I forget it
        Then the ssh config still has the Host {'handmade'}
        And the machine {'handmade'} is no longer watched

    # One name wherever it is offered, and asked first: what forgetting does is said before it is done.
    Scenario: forgetting a machine says what it does, and does nothing before it is agreed to
        Given the machine {'handmade'} is reached through a Host entry written by hand
        And I switch to the machine {'handmade'}
        When I ask to forget this machine
        Then it says {'This interface stops watching it and takes down the tunnel it raised to it. Nothing on the machine changes: its Porelo, its work and its vault stay as they are, and Watch another machine… adds it again.'}
        And the machine {'handmade'} is still watched
        When I forget it
        Then the machine {'handmade'} is no longer watched

    Scenario: a forward whose login is refused explains why beside the machine on the machines page
        Given raising a forward will fail with {'Permission denied (publickey).'}
        When the wizard set up the machine {'build'}
        Then on the machines page {'build'} shows the refusal {'porelo-build accepted none of the keys your ssh agent offered'}
        And on the machines page {'build'} shows the refusal {'It would log in with ~/.ssh/porelo-build-agent'}
