# The Feature line is the report row: one short sentence, 70 characters at most,
# saying what this file tests. It is the group name in every surface CI renders.
# Linux only: setup reaches the real private SSH config writer, which invokes chmod.
@linux
Feature: Adding a machine through a wizard that starts from what you have

    Background:
        Given a backend with work on it
        And the app is running
        And I go to the work
        When I open the machine dialog

    # Walk 9: whether the person may run commands as root there is asked first. Only
    # then is the machine set up from here; otherwise a Porelo somebody else set up is connected to.
    Scenario: the first page asks whether the person is an administrator there, then how to reach it
        Then the dialog offers {'Yes: I may run commands as root there'}
        And the dialog offers {'No: somebody else set Porelo up there for me'}
        When I choose {'Yes: I may run commands as root there'}
        Then the dialog offers {'Its socket is already forwarded'}
        And the dialog offers {'Raise the forward for me'}
        And the dialog offers {'A new machine'}
        And the dialog offers {'Another user on a machine already prepared'}

    Scenario: one who is not an administrator there is offered only to connect
        When I choose {'No: somebody else set Porelo up there for me'}
        Then the dialog offers {'Raise the forward for me'}
        And the dialog offers {'Its socket is already forwarded'}
        And the dialog does not offer {'A new machine'}
        And the dialog does not offer {'Another user on a machine already prepared'}

    # Nothing is preselected: the kinds are different commitments, and a default would choose one.
    Scenario: the wizard goes on only with a name and a kind
        When I say it is called {'the build machine'}
        Then the wizard cannot go on yet
        When I choose {'Raise the forward for me'}
        And I go on
        Then its socket there is not filled in

    Scenario: a kind without a name does not go on either
        When I choose {'Its socket is already forwarded'}
        Then the wizard cannot go on yet

    Scenario: going back keeps what was said, and another kind can be chosen
        When I say it is called {'the build machine'}
        And I choose {'Raise the forward for me'}
        And I go on
        And I say it is at {'user@build.example.test'}
        And I go back
        And I choose {'Its socket is already forwarded'}
        And I go on
        And the forwarded socket is {'/tmp/porelo-build.sock'}
        And I watch it
        Then nothing was raised for {'the build machine'}

    # A machine that cannot run a task is said so before the first start. What it says is the daemon's
    # own answer, as `porelo doctor` gives it, and it is added either way. Adding it does not move what
    # is being acted on, so it is read when the person goes there.
    Scenario: a machine added is asked whether it can run work when the person goes there
        When I say it is called {'the build machine'}
        And I choose {'Its socket is already forwarded'}
        And I go on
        And the forwarded socket is {'/tmp/porelo-build.sock'}
        And I watch it
        Then it does not say {'This machine can run work'}
        When I switch to the machine {'the build machine'}
        Then it says {'This machine can run work. Nothing is missing.'}

    # BatchMode fails on an unknown key rather than asking, and a key accepted unseen is the one step
    # somebody in the middle needs. So it is shown, and trusting it is a separate act.
    Scenario: a host reached for the first time shows its key before anything logs in
        Given the host key of {'user@build.example.test'} is not known yet
        When I say it is called {'the build machine'}
        And I choose {'Raise the forward for me'}
        And I say it is at {'user@build.example.test'}
        And its socket there is {'/run/user/1001/porelo/porelod.sock'}
        And I try the connection
        Then I am shown the host key {'SHA256:uNiQuEfInGeRpRiNtOfThEbUiLdMaChInE0123456789'}
        And nothing was raised for the trial
        When I trust the host key
        Then the host key of {'build.example.test'} was written
        And the trial says {'Reached Porelo'}

    Scenario: a host key that is not trusted is never written, and nothing is tried
        Given the host key of {'user@build.example.test'} is not known yet
        When I say it is called {'the build machine'}
        And I choose {'Raise the forward for me'}
        And I say it is at {'user@build.example.test'}
        And its socket there is {'/run/user/1001/porelo/porelod.sock'}
        And I try the connection
        And I do not trust the host key
        Then no host key was written
        And the trial says {'was not trusted, so nothing was tried'}
        And nothing was raised for the trial

    Scenario: watching without trying asks about the key too
        Given the host key of {'user@build.example.test'} is not known yet
        When I say it is called {'the build machine'}
        And I choose {'Raise the forward for me'}
        And I say it is at {'user@build.example.test'}
        And its socket there is {'/run/user/1001/porelo/porelod.sock'}
        And I watch it
        Then I am shown the host key {'SHA256:uNiQuEfInGeRpRiNtOfThEbUiLdMaChInE0123456789'}
        When I do not trust the host key
        Then no host key was written
        And nothing was raised for {'the build machine'}

    Scenario: a host already known is not asked about
        When I say it is called {'the build machine'}
        And I choose {'Raise the forward for me'}
        And I say it is at {'user@build.example.test'}
        And its socket there is {'/run/user/1001/porelo/porelod.sock'}
        And I try the connection
        Then the trial says {'Reached Porelo'}
        And no host key was written

    # A socket somebody else forwarded names no host, so there is no key of one to ask about.
    Scenario: a socket already forwarded is never asked about a host key
        When I say it is called {'the build machine'}
        And I choose {'Its socket is already forwarded'}
        And the forwarded socket is {'/tmp/porelo-build.sock'}
        And I try the connection
        And I watch it
        Then no host key was asked about

    # The key before the machine: one made afterwards cannot reach a machine that only knows root's.
    # Linux only: preparing a machine over ssh with keys in ~/.ssh is the Linux build's way; on
    # Windows the wizard offers a WSL distribution.
    @linux
    Scenario: root logs in with that key once its host key is trusted
        Given the host key of {'root@203.0.113.10'} is not known yet
        When I say it is called {'the build machine'}
        And I choose {'A new machine'}
        And I go on
        And I use my person identity
        And I go to the next step
        And I say the new machine is at {'203.0.113.10'}
        And I try logging in as root
        Then I am shown the host key {'SHA256:uNiQuEfInGeRpRiNtOfThEbUiLdMaChInE0123456789'}
        When I trust the host key
        Then root logged in to {'203.0.113.10'} with {'person.pub'}
        And it says {'Logged in as root on 203.0.113.10'}
        When I go to the next step
        Then it says {"Porelo's setup script runs as root"}

    Scenario: a root login that fails says what ssh said, and the wizard does not go on
        Given logging in as root will fail with {'root@203.0.113.10: Permission denied (publickey).'}
        When I say it is called {'the build machine'}
        And I choose {'A new machine'}
        And I go on
        And I use my person identity
        And I go to the next step
        And I say the new machine is at {'203.0.113.10'}
        And I try logging in as root
        Then it says {'Permission denied (publickey).'}
        And the wizard cannot go to the next step yet

    Scenario: a host key that is not trusted logs nothing in
        Given the host key of {'root@203.0.113.10'} is not known yet
        When I say it is called {'the build machine'}
        And I choose {'A new machine'}
        And I go on
        And I use my person identity
        And I go to the next step
        And I say the new machine is at {'203.0.113.10'}
        And I try logging in as root
        And I do not trust the host key
        Then it says {'was not trusted, so nothing logged in'}
        And root never logged in

    # What the person reads is the script's own --show, and nothing changes until they run it.
    Scenario: the setup script shows what it would do before anything runs
        Given a new machine whose root logs in
        When I see what it can install
        And I fetch the setup script
        Then it shows what the setup script would run {'useradd --create-home agent'}
        And the setup script has not run yet
        When I run the setup script
        Then it says {'The machine is prepared.'}
        And the setup script ran for {'agent'}

    Scenario: an operating system the script does not know is said, and nothing can run
        Given a new machine whose root logs in
        And the setup script does not know this operating system
        When I see what it can install
        Then it says {'does not know this operating system'}
        And it says {'Arch Linux'}
        And the setup script cannot be run
        And the setup script has not run yet

    Scenario: a failed check leaves the wizard where it is
        Given a new machine whose root logs in
        And the setup script will end with {5}
        When I see what it can install
        And I fetch the setup script
        And I run the setup script
        Then it says {'A check failed and the machine is not usable yet'}
        And the wizard cannot go to the next step yet

    # The Host entry is the work user's, never root's, and the forward is raised the way watching it will.
    # Linux only: preparing a machine over ssh with keys in ~/.ssh is the Linux build's way; on
    # Windows the wizard offers a WSL distribution.
    @linux
    Scenario: the prepared machine is reached as the work user and watched
        Given a new machine whose root logs in
        When I see what it can install
        And I fetch the setup script
        And I run the setup script
        And I go to the next step
        And I set it up and connect
        Then the key was allowed for {'agent'}
        And ssh config reaches {'porelo-the-build-machine'} as {'agent'} with {'person.pub'}
        And Porelo was started as the work user
        And it says {'Reached Porelo'}
        And it says {'Ready to watch.'}
        And nothing porelo doctor found is shown
        When I watch the new machine
        Then the forward was raised through {'porelo-the-build-machine'} to {'/run/user/1001/porelo/porelod.sock'}

    # The setup script's exit says its steps ran; porelo doctor is the check. Measured on a rented
    # Ubuntu 24.04: prepared, answering, and podman too old for any task.
    Scenario: a machine porelo doctor refuses can be watched, and what doctor found is said
        Given a new machine whose root logs in
        And porelo doctor will refuse with {'podman 4.9.3 is too old'}
        When I see what it can install
        And I fetch the setup script
        And I run the setup script
        And I go to the next step
        And I set it up and connect
        Then it says {'tasks cannot run there yet'}
        And it does not say {'Ready to watch.'}
        And what porelo doctor found is shown {'podman 4.9.3 is too old'}
        When I watch the new machine
        Then the forward was raised through {'porelo-the-build-machine'} to {'/run/user/1001/porelo/porelod.sock'}

    Scenario: porelo doctor asked again after a fix at the machine says it is ready
        Given a new machine whose root logs in
        And porelo doctor will refuse with {'podman 4.9.3 is too old'}
        When I see what it can install
        And I fetch the setup script
        And I run the setup script
        And I go to the next step
        And I set it up and connect
        And porelo doctor passes now
        And I ask porelo doctor again
        Then it says {'Ready to watch.'}
        And nothing porelo doctor found is shown

    Scenario: turning off root login is offered, and done only when asked
        Given a new machine whose root logs in
        When I see what it can install
        And I fetch the setup script
        And I run the setup script
        And I go to the next step
        And I set it up and connect
        Then root login was not turned off
        When I turn off root and password login
        Then it says {'Logging in as root and with a password is off.'}
        And root login was turned off

    Scenario: the work user is the one the options name
        Given new machines run work as {'builder'}
        And a new machine whose root logs in
        When I see what it can install
        And I fetch the setup script
        Then the setup script was shown for {'builder'}


    Scenario: a key that cannot be allowed for the work user stops before anything else is written
        Given a new machine whose root logs in
        And allowing the key for the work user will fail with {'getent: no such user'}
        When I see what it can install
        And I fetch the setup script
        And I run the setup script
        And I go to the next step
        And I set it up and connect
        Then it says {'The key could not be allowed for agent: getent: no such user'}
        And ssh config was not touched
        And Porelo was not started

    # The machine's own package source is the catalog; the interface never asks a repository.
    Scenario: what it can install is offered as choices, and what is there is shown fixed
        Given a new machine whose root logs in
        When I see what it can install
        Then it offers the package {'porelo-agent-claude'}
        And it offers the package {'porelo-agent-omp'}
        And the package {'porelo-message-transport-matrix'} is shown installed and cannot be unticked
        And nothing was installed by asking

    Scenario: a chosen agent is shown and run with the rest
        Given a new machine whose root logs in
        When I see what it can install
        And I choose the package {'porelo-agent-claude'}
        And I fetch the setup script
        Then the setup script was shown with {'porelo-agent-claude'}
        When I run the setup script
        Then the setup script ran with {'porelo-agent-claude'}

    # What runs is only ever what was shown.
    Scenario: changing the choice after it was shown asks for it to be shown again
        Given a new machine whose root logs in
        When I see what it can install
        And I fetch the setup script
        And I choose the package {'porelo-agent-omp'}
        Then it says {'Show it again before it runs'}
        And the setup script cannot be run

    Scenario: an empty catalog says why
        Given a new machine whose root logs in
        And the machine's package source offers nothing yet
        When I see what it can install
        Then it says {'nothing yet'}


    Scenario: the wizard offers the user that runs work, and a name no machine would accept stops it
        When I say it is called {'the build machine'}
        And I choose {'A new machine'}
        Then the user that runs work is offered as {'agent'}
        When I say the user that runs work is {'Not Valid'}
        Then the wizard cannot go on yet
        When I say the user that runs work is {'builder'}
        And I go on
        And I use my person identity
        And I go to the next step
        And I say the new machine is at {'203.0.113.10'}
        And I try logging in as root
        And I go to the next step
        And I see what it can install
        And I fetch the setup script
        Then the setup script was shown for {'builder'}

    # The second wizard: only the parts that make a user, with the key the machine already knows.
    # Linux only: preparing a machine over ssh with keys in ~/.ssh is the Linux build's way; on
    # Windows the wizard offers a WSL distribution.
    @linux
    Scenario: another user is added to a machine prepared before, and watched as a machine of its own
        When I cancel the dialog
        And I choose the command {'Add another user that runs work…'}
        Then the wizard offers no kind to choose
        When I say it is called {'the build machine as other'}
        And I say the user that runs work is {'other'}
        And I go on
        And I use my person identity
        And I go to the next step
        And I say the new machine is at {'203.0.113.10'}
        And I try logging in as root
        And I go to the next step
        Then nothing asks what it can install
        When I fetch the setup script
        And I run the setup script
        Then the setup script ran for {'other'}
        When I go to the next step
        And I set it up and connect
        Then ssh config reaches {'porelo-the-build-machine-as-other'} as {'other'} with {'person.pub'}
        When I watch the new machine
        Then the forward was raised through {'porelo-the-build-machine-as-other'} to {'/run/user/1001/porelo/porelod.sock'}

    Scenario: going back and on again keeps the key and where the machine is
        When I say it is called {'the build machine'}
        And I choose {'A new machine'}
        And I go on
        And I use my person identity
        And I go to the next step
        And I say the new machine is at {'203.0.113.10'}
        And I go back
        And I go back
        And I go on
        When I go to the next step
        Then the new machine is at {'203.0.113.10'}

    Scenario: a setup that was not finished is offered to be continued where it stopped
        Given a new machine whose root logs in
        When I cancel the dialog
        And I open the machine dialog
        Then it says {'Setting up the build machine (203.0.113.10) was not finished.'}
        When I continue the unfinished setup
        Then the new machine is at {'203.0.113.10'}
        When I try logging in as root
        And I go to the next step
        Then it says {"Porelo's setup script runs as root"}

    Scenario: an unfinished setup that is discarded is not offered again
        Given a new machine whose root logs in
        When I cancel the dialog
        And I open the machine dialog
        And I discard the unfinished setup
        And I cancel the dialog
        And I open the machine dialog
        Then no unfinished setup is offered

    # Going back or on in the middle of it would draw a step that is not true yet.
    Scenario: while a script runs it says what it is doing, and only Cancel is offered
        Given a new machine whose root logs in
        And the machine takes its time answering
        When I start asking what it can install
        Then it says {'Asking the machine what it can install'}
        And it shows the first line the machine printed
        And only Cancel is offered
        When the machine answers
        Then it offers the package {'porelo-agent-claude'}

    # The third way to a key: one already in ~/.ssh, used where it is rather than copied.
    # Linux only: preparing a machine over ssh with keys in ~/.ssh is the Linux build's way; on
    # Windows the wizard offers a WSL distribution.
    @linux
    Scenario: a host whose key changed is warned about, and the old key is replaced only when asked
        Given the host key of {'root@203.0.113.10'} changed since it was last seen
        When I say it is called {'the build machine'}
        And I choose {'A new machine'}
        And I go on
        And I use my person identity
        And I go to the next step
        And I say the new machine is at {'203.0.113.10'}
        And I try logging in as root
        Then I am warned that the key is not the one known for that address
        When I trust the host key
        Then the host key of {'203.0.113.10'} was written
        And root logged in to {'203.0.113.10'} with {'person.pub'}

    # What is shown before running is shown once, in its box; below "Run it as root" is only what running printed.
    Scenario: nothing is shown below the run until it was run
        Given a new machine whose root logs in
        When I see what it can install
        And I fetch the setup script
        Then it shows what the setup script would run {'useradd --create-home agent'}
        And nothing is shown below the run yet
        When I run the setup script
        Then what running it printed is shown below it {'porelo installed'}

    Scenario: hooks that cannot be registered stop the wizard before anything is watched
        Given a new machine whose root logs in
        And registering Porelo's hooks will fail with {'podman: cannot write hooks.d'}
        When I see what it can install
        And I fetch the setup script
        And I run the setup script
        And I go to the next step
        And I set it up and connect
        Then it says {'porelo setup did not register what a task needs: podman: cannot write hooks.d'}
        And the wizard cannot go to the next step yet

    # Decided: the passphrase goes keyboard → terminal → ssh → porelo, never
    # through this program, and whether the vault is there is asked of the daemon, not read off the terminal.
    Scenario: the vault is made in a terminal as the work user, and the daemon says it is there
        Given a new machine whose root logs in
        And the machine has no vault
        When I see what it can install
        And I fetch the setup script
        And I run the setup script
        And I go to the next step
        And I set it up and connect
        And I go to the next step
        And I open the terminal to make the vault
        Then the terminal runs {'ssh -t porelo-the-build-machine porelo vault init'}
        When the terminal ends with {0}
        Then it says {'The vault is there, and it opens with the passphrase typed.'}

    # Required: a machine left with no vault refused the first credential later, far
    # from where the vault is made.
    Scenario: the vault step is not left while the machine has no vault
        Given a new machine whose root logs in
        And the machine has no vault
        When I see what it can install
        And I fetch the setup script
        And I run the setup script
        And I go to the next step
        And I set it up and connect
        And I go to the next step
        Then the next step of setting it up is offered {false}
        When I open the terminal to make the vault
        And the terminal ends with {0}
        Then the next step of setting it up is offered {true}

    # Said before anything runs, where it can still be chosen: found after, it was a second run as root.
    Scenario: a choice with no transport is said before the setup script runs
        Given a new machine whose root logs in
        And the machine has no transport yet
        When I see what it can install
        Then it says {'With no transport chosen, its work cannot send or receive messages'}
        When I choose the package {'porelo-message-transport-matrix'}
        Then it does not say {'With no transport chosen'}
        But it says {'The transport alone carries messages only for a project that names a homeserver'}
        When I choose the package {'porelo-matrix-homeserver'}
        Then it does not say {'The transport alone'}

    # The homeserver depends on the transport, so it brings it.
    Scenario: choosing the homeserver alone is enough to carry messages
        Given a new machine whose root logs in
        And the machine has no transport yet
        When I see what it can install
        And I choose the package {'porelo-matrix-homeserver'}
        Then it does not say {'With no transport chosen'}
        And it does not say {'The transport alone'}

    Scenario: whether the new machine can carry messages is said once it answers
        Given a new machine whose root logs in
        When I see what it can install
        And I fetch the setup script
        And I run the setup script
        And I go to the next step
        And I set it up and connect
        Then it says {'It can carry its projects’ messages'}

    Scenario: a machine with the transport and no homeserver is said to need one
        Given a new machine whose root logs in
        And the machine has no homeserver package
        When I see what it can install
        And I fetch the setup script
        And I run the setup script
        And I go to the next step
        And I set it up and connect
        Then it says {'no homeserver is'}

    Scenario: a terminal that ended without a vault says so, and it can be opened again
        Given a new machine whose root logs in
        And the machine has no vault
        When I see what it can install
        And I fetch the setup script
        And I run the setup script
        And I go to the next step
        And I set it up and connect
        And I go to the next step
        And I open the terminal to make the vault
        And the terminal ends with {70}
        Then it says {'There is no vault yet'}
        And the terminal can be opened again
        When I open the terminal to make the vault
        Then the terminal it replaced was closed

    # Its connections need the daemon the wizard has only just made reachable, so they are its last
    # step, taken once the machine is watched.
    Scenario: the wizard ends by setting up how the new machine connects out
        Given a new machine whose root logs in
        When I see what it can install
        And I fetch the setup script
        And I run the setup script
        And I go to the next step
        And I set it up and connect
        And I watch the new machine, then set up how it connects out
        Then it says {'Connections — how the build machine connects out'}
        And adding a connection is offered

    # Found in use: asked before the new machine's socket answered, an unhandled error.
    Scenario: the connections of a new machine are asked once it answers, not before
        Given a new machine whose root logs in
        When I see what it can install
        And I fetch the setup script
        And I run the setup script
        And I go to the next step
        And I set it up and connect
        And the new machine answers only after a moment
        And I watch the new machine, then set up how it connects out
        And the new machine answers
        Then it says {'Connections — how the build machine connects out'}
        And it does not say {'has not answered yet'}
        And adding a connection is offered

