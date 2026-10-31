# The Feature line is the report row: one short sentence, 70 characters at most,
# saying what this file tests. It is the group name in every surface CI renders.
Feature: Starting work with an agent, a mode and a credential

    Background:
        Given a backend with work on it
        And the app is running
        And I go to the work
        And I select the project {'checkout'}

    # Pressing start is answered at once; the machine is asked behind the open dialog. Waiting for it
    # first left the press without any sign, and it was pressed twice.
    Scenario: the start dialog opens at once, and says it is still asking the machine
        Given reading the agents is slow
        When I start work in this project
        Then it says {'Asking the machine what it has'}
        When the machine has answered
        Then it does not say {'Asking the machine what it has'}

    # Measured on the test machine: CanStart said the agent was not installed while Agents listed it,
    # and asking again answered ready. Start it stayed off until somebody chose the agent again.
    Scenario: an agent the machine lists, refused once as not installed, is asked about again
        Given the machine refuses the agent as not installed {1} times
        When I start work in this project
        And I call it {'schema-work'}
        And I choose the agent {'An Agent'}
        Then it does not say {'is not installed on this machine'}
        When I start it
        Then the launch was called {'schema-work'}

    Scenario: an agent refused as not installed is named in the sentence
        Given the machine refuses the agent as not installed {5} times
        When I start work in this project
        And I choose the agent {'An Agent'}
        Then it says {'an-agent is not installed on this machine'}

    Scenario: work is started with a name, an agent and a mode
        When I start work in this project
        And I call it {'schema-work'}
        And I choose the agent {'An Agent'}
        And I start it
        Then the launch was called {'schema-work'}
        And the launch asked for the mode {'AGENT'}
        And the launch named the project {'checkout'}

    # Decided: a name is required, filled in from the repository; an unnamed start was
    # called `shell` by the machine, which read as the wrong way of taking part.
    Scenario: the name is filled in from the repository chosen, and is what the work is called
        Given the project {'checkout'} has the repositories {'checkout, payments-api'}
        When I start work in this project
        And I choose the agent {'An Agent'}
        And I choose the repository {'payments-api'}
        Then the name offered is {'payments-api'}
        When I start it
        Then the launch was called {'payments-api'}

    Scenario: a name somebody typed is kept when the repository changes
        Given the project {'checkout'} has the repositories {'checkout, payments-api'}
        When I start work in this project
        And I call it {'schema-work'}
        And I choose the repository {'payments-api'}
        Then the name offered is {'schema-work'}

    Scenario: without a name nothing starts
        Given the project {'checkout'} has the repositories {'checkout, payments-api'}
        When I start work in this project
        And I choose the agent {'An Agent'}
        And I choose the repository {'payments-api'}
        And I call it {''}
        Then starting is not offered yet

    # Walk 9: a name the project's work has already was refused only when started.
    Scenario: a name the project's work has already is refused as it is typed
        When I start work in this project
        And I call it {'shell'}
        And I choose the agent {'An Agent'}
        Then the name is refused saying {'The name "shell" is taken'}
        And starting is not offered yet

    # A `Foo Bar` was sent, the image was built, and only podman's create refused the name.
    Scenario: a name no container could have is refused before anything starts
        When I start work in this project
        And I call it {'Foo Bar'}
        And I choose the agent {'An Agent'}
        Then the name is refused saying {'cannot hold a space'}
        And starting is not offered yet

    # A case-insensitive filesystem makes Foo and foo one git ref.
    Scenario: a name in upper case is refused, because two of them could be one ref
        When I start work in this project
        And I call it {'Schema-Work'}
        And I choose the agent {'An Agent'}
        Then the name is refused saying {'lowercase'}
        And starting is not offered yet

    Scenario: a name of other characters, or with a hyphen at its edge, is refused
        When I start work in this project
        And I call it {'schema_work-'}
        And I choose the agent {'An Agent'}
        Then the name is refused saying {'starts and ends with a letter or a digit'}
        And starting is not offered yet

    # A login container is porelo-login-<digits>.
    Scenario: a name of only digits is refused
        When I start work in this project
        And I call it {'123'}
        And I choose the agent {'An Agent'}
        Then the name is refused saying {'only digits'}
        And starting is not offered yet

    # The container name holds the prefix, and the task's longest socket path has to fit.
    Scenario: a name too long for its project is refused, saying how long it may be
        When I start work in this project
        And I call it {'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'}
        And I choose the agent {'An Agent'}
        Then the name is refused saying {'at most 65 fit'}
        And starting is not offered yet

    # The machine's rule is the authority, and its sentence carries a name that would do.
    # Named last, so only typing it can have asked the machine about it.
    Scenario: a name the machine refuses is refused in its words
        Given the machine refuses the name {'login-7'} saying {'kept for login containers - login7 would do'}
        When I start work in this project
        And I choose the agent {'An Agent'}
        And I call it {'login-7'}
        Then the name is refused saying {'login7 would do'}
        And starting is not offered yet
        And the machine was asked about the name {'login-7'}

    # Decided: a first start lands in the agent's session, not in a shell to type it into.
    Scenario: a start works through the agent's session unless somebody chooses otherwise
        When I start work in this project
        And I choose the agent {'An Agent'}
        Then the way of taking part chosen is {'A shell, driven by hand'}

    Scenario: an unattended run is not started without being told what to do
        When I start work in this project
        And I choose the agent {'An Agent'}
        And I choose {'Unattended, against a prompt'}
        Then starting is not offered yet

    Scenario: a prompt belongs to an unattended run and to nothing else
        When I start work in this project
        And I choose the agent {'An Agent'}
        Then what to ask it cannot be filled in

    Scenario: what was chosen is what is sent
        When I start work in this project
        And I choose the agent {'An Agent'}
        And I choose {'Unattended, against a prompt'}
        And I ask it to {'Fix the rounding and add a test'}
        And I start it
        Then the launch asked for the mode {'UNATTENDED'}
        And the launch asked it to {'Fix the rounding and add a test'}

    Scenario: an unattended run goes to the session, so leaving the dialog does not stop watching
        When I start work in this project
        And I choose the agent {'An Agent'}
        And I choose {'Unattended, against a prompt'}
        And I ask it to {'Fix the rounding and add a test'}
        And I start it
        And the operation prints {'agent: reading lib/money.dart'}
        Then the operation shows {'agent: reading lib/money.dart'}

    Scenario: a finished unattended run is continued with what it was asked to do last time
        When I select the work {'porelo-checkout-migrate'}
        And I continue this work
        Then what to ask it says {'Fix the rounding in Money.pennies'}

    Scenario: work that is still running is not offered a new prompt
        When I select the work {'porelo-checkout-shell'}
        And I open the command finder
        Then the command {'Continue this work with a new prompt'} is offered as unavailable

    Scenario: an agent that could not be read is named rather than left out
        Given one agent on the machine cannot be read
        When I start work in this project
        Then it says {'could not be read'}

    Scenario: a prompt typed and then set aside is not sent with a mode that has no use for it
        When I start work in this project
        And I choose the agent {'An Agent'}
        And I choose {'Unattended, against a prompt'}
        And I ask it to {'Fix the rounding and add a test'}
        And I choose {'A shell, driven by hand'}
        And I start it
        Then the launch asked for the mode {'AGENT'}
        And the launch was asked for nothing in particular

    Scenario: a missing credential is named before anything is started
        Given the vault holds no credential for what a run would use
        When I start work in this project
        And I choose the agent {'An Agent'}
        Then it says {'The vault holds no credential called a-provider'}
        And nothing was started

    # A missing credential is stored from where it was found missing, by the line the machine names
    # for its provider, in a terminal there — and then the machine is asked again.
    Scenario: a missing credential is stored from the start dialog, and starting is asked about again
        Given the vault holds no credential for what a run would use
        When I start work in this project
        And I choose the agent {'An Agent'}
        And I store the credential from the start
        Then a terminal runs {'sh -c porelo vault put a-provider'} on the machine
        When the unlock terminal ends and is put away
        Then whether work can start is asked again

    Scenario: a machine that cannot say how to store a credential says so, rather than nothing
        Given the vault holds no credential for what a run would use
        And the machine cannot say its providers
        When I start work in this project
        And I choose the agent {'An Agent'}
        And I store the credential from the start
        Then the status line mentions {'could not say how to store'}

    # A login prints its page as an OSC 8 link. It is offered to be opened here — never opened by
    # itself, and never anything but a web address.
    Scenario: a link the terminal marks is opened in the browser here with a press, and only then
        Given the vault holds no credential for what a run would use
        When I start work in this project
        And I choose the agent {'An Agent'}
        And I store the credential from the start
        And the terminal prints a link to {'https://claude.com/cai/oauth/authorize?code=true'}
        Then nothing was opened in the browser
        When I open the link to {'https://claude.com/cai/oauth/authorize?code=true'}
        Then the browser was given {'https://claude.com/cai/oauth/authorize?code=true'}

    Scenario: a link that is not a web address is never offered
        Given the vault holds no credential for what a run would use
        When I start work in this project
        And I choose the agent {'An Agent'}
        And I store the credential from the start
        And the terminal prints a link that would run {'file:///usr/bin/xcalc'}
        Then the terminal offers no link

    # The agent's own login, where it declares one: its page is a link to open here, and its reply
    # to localhost is forwarded to the machine for as long as the login's terminal is open.
    Scenario: an agent that declares a login is logged in from the start, its reply forwarded
        Given the vault holds no credential for what a run would use
        And the agent {'an-agent'} logs in by its own login
        When I start work in this project
        And I choose the agent {'An Agent'}
        And I log in with the agent from the start
        Then a terminal runs {'porelo vault login --agent an-agent'} on the machine
        When the login prints its page {'https://claude.com/cai/oauth/authorize'} and its reply port {'42017'}
        Then the reply port {'42017'} is forwarded
        And nothing was opened in the browser
        When I open the link to {'https://claude.com/cai/oauth/authorize'}
        Then the browser was given {'https://claude.com/cai/oauth/authorize'}
        # A login that builds an image first prints nothing for minutes: said, and not put away by a press.
        And the terminal says {'The first sign-in builds'}
        And the terminal offers no Done while it runs
        When I cancel the sign-in and let it run after all
        Then the terminal says {'The first sign-in builds'}
        When the unlock terminal ends and is put away
        Then the reply forward is taken down
        And whether work can start is asked again

    # The address is the daemon's, and one that does not parse is not offered as a link.
    Scenario: how an agent's login works is offered when its address is one
        Given the vault holds no credential for what a run would use
        And the agent {'an-agent'} documents its login at {'https://docs.example.test/login'}
        When I start work in this project
        And I choose the agent {'An Agent'}
        Then it says {'How this login works'}

    Scenario: an address that is not one is not offered as a link
        Given the vault holds no credential for what a run would use
        And the agent {'an-agent'} documents its login at {'http://[not an address'}
        When I start work in this project
        And I choose the agent {'An Agent'}
        Then it does not say {'How this login works'}

    # An agent may print a link of its own beside the machine's. The machine marks its own, and that is
    # the one offered first: its reply comes back without a code. The other stays, for an agent without one.
    Scenario: the machine's login page is offered first, and a link of the agent's own below it
        Given the vault holds no credential for what a run would use
        And the agent {'an-agent'} logs in by its own login
        When I start work in this project
        And I choose the agent {'An Agent'}
        And I log in with the agent from the start
        And the agent prints a link of its own to {'https://claude.com/cai/oauth/authorize?code=true'}
        And the login prints its page {'https://claude.com/cai/oauth/authorize'} and its reply port {'42017'}
        Then the first link offered says {'Sign in: the reply comes back here'}, and opens {'https://claude.com/cai/oauth/authorize'}
        And it says {'Another link the program printed'}

    # The standard pair: Claude Code is the agent a start offers first, where it is installed.
    Scenario: Claude Code is chosen where it is installed and nobody chose another
        Given the machine has Claude Code installed too
        When I start work in this project
        Then the agent chosen is {'claude'}

    # Reported: a new person pressed "Start it", landed in a shell, and the agent said
    # "Not logged in". With nothing to sign in with, the sign-in comes first, at the top, and no start.
    Scenario: an agent with nothing to sign in with is signed in first, and no start of any kind is offered
        Given the vault holds no credential for what a run would use
        And the agent {'an-agent'} logs in by its own login
        When I start work in this project
        And I choose the agent {'An Agent'}
        Then the form asks to sign in to {'An Agent'} first, above everything else
        And it offers {'Sign in first'} instead of starting
        When I press {'Sign in first'}
        Then a terminal runs {'porelo vault login --agent an-agent'} on the machine

    Scenario: a sign-in that stored the credential says so, and the form moves on to the start
        Given the vault holds no credential for what a run would use
        And the agent {'an-agent'} logs in by its own login
        When I start work in this project
        And I choose the agent {'An Agent'}
        And I log in with the agent from the start
        And the login stores what it signed in with
        And the unlock terminal ends
        Then the terminal ends saying {'Signed in to An Agent: the credential is stored'}
        And no link is offered any more
        When I press {'Done'}
        Then the form no longer asks to sign in

    Scenario: a paste-code sign-in says above the terminal what to do
        Given the vault holds no credential for what a run would use
        And the agent {'an-agent'} logs in by its own login
        And the agent {'an-agent'} signs in by the flow {'paste-code'}
        When I start work in this project
        And I choose the agent {'An Agent'}
        And I log in with the agent from the start
        Then a terminal runs {'porelo vault login --agent an-agent'} on the machine
        And the terminal is headed by {'Paste the code shown in your browser'}

    Scenario: a device-code sign-in says above the terminal what to do
        Given the vault holds no credential for what a run would use
        And the agent {'an-agent'} logs in by its own login
        And the agent {'an-agent'} signs in by the flow {'device-code'}
        When I start work in this project
        And I choose the agent {'An Agent'}
        And I log in with the agent from the start
        Then a terminal runs {'porelo vault login --agent an-agent'} on the machine
        And the terminal is headed by {'Confirm on the device page'}

    # A definition naming no flow, or one this interface does not know, is promised none of them.
    Scenario: a sign-in of an unknown flow says only to follow the terminal
        Given the vault holds no credential for what a run would use
        And the agent {'an-agent'} logs in by its own login
        And the agent {'an-agent'} signs in by the flow {'qr-code'}
        When I start work in this project
        And I choose the agent {'An Agent'}
        And I log in with the agent from the start
        Then a terminal runs {'porelo vault login --agent an-agent'} on the machine
        And the terminal is headed by {'Then follow what the terminal below says'}
        And the terminal is not headed by {'Paste the code'}
        And the terminal is not headed by {'Confirm on the device page'}
        And the terminal is not headed by {'hands the answer back'}

    # Core refuses a loopback sign-in in a host account before it starts: its words stay in the terminal,
    # nothing is stored, and the start stays behind the sign-in.
    Scenario: a loopback sign-in the host refuses stores nothing and starts nothing
        Given the vault holds no credential for what a run would use
        And the agent {'an-agent'} logs in by its own login
        And the agent {'an-agent'} signs in by the flow {'loopback'}
        When I start work in this project
        And I choose the agent {'An Agent'}
        And I log in with the agent from the start
        Then a terminal runs {'porelo vault login --agent an-agent'} on the machine
        When the terminal prints {'porelo: a loopback sign-in cannot run in a host account'}
        And the terminal ends with {65}
        Then the terminal ends saying {'Nothing was stored for An Agent'}
        And the sign-in terminal still shows {'a loopback sign-in cannot run in a host account'}
        When I press {'Done'}
        Then the form asks to sign in to {'An Agent'} first, above everything else
        And nothing was started

    Scenario: an agent that declares no login is not offered one
        Given the vault holds no credential for what a run would use
        When I start work in this project
        And I choose the agent {'An Agent'}
        Then logging in is not offered

    Scenario: the credential is stored by the command the readiness answer names
        Given starting says the credential is stored by {'porelo vault put a-provider'}
        When I start work in this project
        And I choose the agent {'An Agent'}
        And I store the credential from the start
        Then a terminal runs {'porelo vault put a-provider'} on the machine

    # Read before a start where no mirror holds the repository yet. The detail ends with the command
    # that fixes it, and a refused key is fixed on the machine.
    Scenario: an upstream that refused the key is said, its fix selectable, with a terminal there
        Given starting says the upstream refused the key, with {'tried the deploy key checkout-deploy. Run: porelo project key checkout'}
        When I start work in this project
        And I choose the agent {'An Agent'}
        Then it says {'refused what this machine offered for it'}
        And the reason for not starting can be selected
        When I fix it in a terminal from the start
        Then a terminal runs {'bash -l'} on the machine
        When the unlock terminal ends and is put away
        Then whether work can start is asked again

    # An unreachable host is often fixed by waiting, so every cause can be asked about again.
    Scenario: an upstream nothing answered for is asked about again
        Given starting says nothing answered from the upstream
        When I start work in this project
        And I choose the agent {'An Agent'}
        Then it says {'within ten seconds'}
        And fixing it in a terminal is not offered
        When I ask again from the start
        Then whether work can start is asked again

    # Asked behind an open dialog nobody awaits: a failure let through there reaches nobody but the
    # console, and the dialog sits as if it had asked nothing.
    Scenario: a machine that fails to say whether work can start is said in the dialog
        Given the machine fails to say whether work can start, with {'the vault could not be read'}
        When I start work in this project
        And I choose the agent {'An Agent'}
        Then it says {'The machine could not say whether work can start: the vault could not be read'}

    # Choosing to work by hand is choosing to be in the work: once it is up, its session opens,
    # rather than a log of the start somebody then has to leave to find the work.
    Scenario: work started to be driven by hand opens its session once it is up
        When I start work in this project
        And I call it {'schema-work'}
        And I choose the agent {'An Agent'}
        And I start it
        And the start brings up {'porelo-checkout-schema-work'} in {'checkout'}, running {'SHELL'}
        Then the session on screen is {'porelo-checkout-schema-work'}

    # An unattended run has nobody at it: its log is what there is to watch.
    Scenario: an unattended run opens no session when it is up
        When I start work in this project
        And I call it {'nightly'}
        And I choose the agent {'An Agent'}
        And I choose {'Unattended, against a prompt'}
        And I ask it to {'run the tests'}
        And I start it
        And the start brings up {'porelo-checkout-nightly'} in {'checkout'}, running {'UNATTENDED'}
        Then no session was opened

    Scenario: a locked vault is a different sentence, and points at the machine
        Given the vault is locked
        When I start work in this project
        And I choose the agent {'An Agent'}
        Then it says {'Unlock it at the machine'}
        And it says {'a daemon has no terminal'}
        And opening it with this device is not offered

    Scenario: a missing credential is not answered by opening the vault, even on an enrolled device
        Given this device is enrolled on the machine
        And the vault holds no credential for what a run would use
        When I start work in this project
        And I choose the agent {'An Agent'}
        Then opening it with this device is not offered

    Scenario: a locked vault is opened from the start with this device, where it is enrolled, and asked again
        Given this device is enrolled on the machine
        And the vault is locked
        When I start work in this project
        And I choose the agent {'An Agent'}
        And I open the vault from the start with this device {'for an hour'}
        Then the machine was asked to open it for {60} minutes
        And whether work can start is asked again once the vault is open

    Scenario: choosing a provider is not storing a secret
        Given the agent names no default provider
        When I start work in this project
        And I choose the agent {'An Agent'}
        Then it says {'this is a provider, not a secret'}

    Scenario: an unattended run that cannot authenticate is not offered at all
        Given the vault is locked
        When I start work in this project
        And I choose the agent {'An Agent'}
        And I choose {'Unattended, against a prompt'}
        And I ask it to {'Fix the rounding'}
        Then starting is not offered yet
        And it says {'no container, no workspace, nothing to clear up'}

    Scenario: an interactive run is offered anyway, and says what it will cost
        Given the vault is locked
        When I start work in this project
        And I choose the agent {'An Agent'}
        Then it says {'a container you will have to clear up'}


    # Decided: work always starts in a named repository, and none is chosen
    # for anybody — not even when there is only one.
    Scenario: work starts in a repository somebody chose, never in one chosen for them
        Given the project {'checkout'} has the repositories {'checkout, payments-api, billing'}
        When I start work in this project
        And I choose the agent {'An Agent'}
        Then no repository is chosen yet
        And starting is not offered yet
        And nothing warns about starting
        When I choose the repository {'payments-api'}
        Then the machine was asked whether work can start in {'payments-api'}
        When I start it
        Then the launch was in the repository {'payments-api'}

    # A project naming others under `repositories:` is never worked in itself: it holds the file, the
    # planning and the issues, and the machine refuses a start there.
    Scenario: a project that names other repositories never offers its own to work in
        Given the project {'checkout'} has the repositories {'checkout, payments-api, billing'}
        When I start work in this project
        Then the repository {'checkout'} is not offered to start in
        And no repository is chosen yet

    Scenario: a project with one repository to work in has it chosen
        Given the project {'checkout'} has the repositories {'checkout, payments-api'}
        When I start work in this project
        Then the repository {'checkout'} is not offered to start in
        And the repository chosen is {'payments-api'}

    # A repository still to choose is not a refusal, even for a run nobody watches.
    Scenario: an unattended run waiting for its repository is not told it would be refused
        Given the project {'checkout'} has the repositories {'checkout, payments-api, billing'}
        When I start work in this project
        And I choose the agent {'An Agent'}
        And I choose {'Unattended, against a prompt'}
        And I ask it to {'Fix the rounding'}
        Then starting is not offered yet
        And nothing warns about starting

    # A Porelo older than repositories per project names no repositories and is sent none.
    Scenario: a machine that names no repositories is asked for none
        When I start work in this project
        And I choose the agent {'An Agent'}
        And I start it
        Then the launch named no repository

    # Continuing is more of the same work, so it goes on where that work is — not a new choice.
    Scenario: work continued goes on in the repository it worked in
        Given the project {'checkout'} has the repositories {'checkout, payments-api'}
        And the work {'porelo-checkout-migrate'} works in the repository {'payments-api'}
        When I select the work {'porelo-checkout-migrate'}
        And I continue this work
        Then the repository {'payments-api'} is chosen

    # Beyond what the project names: a vault entry for a destination, given by a person, never by default.
    Scenario: work is given a vault entry for a destination, and says how it appears inside
        Given the machine declares the destination {'weather'} at {'https://api.weather.example/v1'}
        When I start work in this project
        And I choose the agent {'An Agent'}
        And I give it the entry {'a-provider'} for {'weather'}
        Then it says {'a-provider for weather, reaching api.weather.example: inside the task as PORELO_TOKEN_A_PROVIDER'}
        When I start it
        Then the launch was given {'a-provider'} for {'weather'}

    Scenario: work is given nothing beyond its project unless somebody gives it
        Given the machine declares the destination {'weather'} at {'https://api.weather.example/v1'}
        When I start work in this project
        And I choose the agent {'An Agent'}
        And I start it
        Then the launch was given nothing beyond its project

    Scenario: a machine without destinations says nothing more can be given
        When I start work in this project
        And I open more options
        Then it says {'No destination is declared on this machine.'}

    # What was given belongs to the work it was given to, not to the dialog the next time.
    Scenario: a vault entry given to work left unstarted is not given to the next
        Given the machine declares the destination {'weather'} at {'https://api.weather.example/v1'}
        When I start work in this project
        And I choose the agent {'An Agent'}
        And I give it the entry {'a-provider'} for {'weather'}
        And I leave without starting
        And I start work in this project
        And I choose the agent {'An Agent'}
        And I start it
        Then the launch was given nothing beyond its project

    # Two files of one name, one in force: the one in force is what the work reaches, and offered once.
    Scenario: a destination put in a package's place is offered once, where it is now
        Given a package declares the destination {'search'} at {'https://api.search.example'}
        And the machine's own {'search'} takes the package's place at {'https://search.internal.example'}
        When I start work in this project
        And I choose the agent {'An Agent'}
        And I give it the entry {'a-provider'} for {'search'}
        Then it says {'a-provider for search, reaching search.internal.example'}

    # A provider is a place an entry can be for as well, as Start takes it.
    Scenario: work is given a vault entry for a provider
        When I start work in this project
        And I choose the agent {'An Agent'}
        And I give it the entry {'a-provider'} for {'A Provider, a provider'}
        Then it says {'a-provider for a-provider, reaching api.example.test'}
        When I start it
        Then the launch was given {'a-provider'} for {'a-provider'}

    # What the project names is given anyway: named, and not offered again to point elsewhere.
    Scenario: the credentials a project names are named when starting, and not offered to give again
        Given the machine declares the destination {'weather'} at {'https://api.weather.example/v1'}
        And the project {'checkout'} names the credential {'a-provider'} for {'weather'}
        When I start work in this project
        And I open more options
        Then it says {'a-provider for weather: inside the task as PORELO_TOKEN_A_PROVIDER'}
        And the entry {'a-provider'} is not offered to give

    Scenario: a project that names no credential of its own says so
        Given the machine declares the destination {'weather'} at {'https://api.weather.example/v1'}
        And the project {'checkout'} names no credential of its own
        When I start work in this project
        And I open more options
        Then it says {'Its project gives it no credential of its own.'}

    # Asked with what it is given, since the answer turns on it.
    Scenario: whether work can start is asked again with the credentials it is given
        Given the machine declares the destination {'weather'} at {'https://api.weather.example/v1'}
        When I start work in this project
        And I choose the agent {'An Agent'}
        And I give it the entry {'a-provider'} for {'weather'}
        Then the machine was last asked whether it can start with {'a-provider'} for {'weather'}

    # Start refuses it in every mode before anything exists, so even a shell is not offered.
    Scenario: a credential for a destination the machine does not declare stops even a shell
        Given the machine declares the destination {'weather'} at {'https://api.weather.example/v1'}
        When I start work in this project
        And I choose the agent {'An Agent'}
        And I give it the entry {'a-provider'} for {'weather'}
        And the destination {'weather'} is no longer declared
        Then it says {'no destination or provider of that name is declared here'}
        And starting is not offered yet

    # From a machine older than that, empty means not said: never shown as "none".
    Scenario: a machine that does not say what a project names says it is not said
        When I start work in this project
        And I open more options
        Then it says {'this machine does not say what that is'}
        And it does not say {'Its project gives it no credential of its own.'}

    # Granting, once, in a browser: offered where it is asked for, and asked about again afterwards.
    Scenario: an entry nobody has granted is granted from the start, and starting is asked about again
        Given nobody has granted {'jira'} yet
        When I start work in this project
        And I choose the agent {'An Agent'}
        Then it says {'Nobody has granted jira yet.'}
        And it says {'It starts, and jira is not granted'}
        And starting is offered
        When I grant it from the start
        And the machine asks for a decision on {'https://auth.example.com/device'} with the code {'WDJB-MJHT'}
        And the machine says the grant is {'granted'}
        And I am done granting
        Then it does not say {'Nobody has granted jira yet.'}

    Scenario: an unattended run is not started without a grant nobody gave
        Given nobody has granted {'jira'} yet
        When I start work in this project
        And I choose the agent {'An Agent'}
        And I choose {'Unattended, against a prompt'}
        And I ask it to {'Sync the tickets'}
        Then it says {'Nobody has granted jira yet.'}
        And starting is not offered yet
