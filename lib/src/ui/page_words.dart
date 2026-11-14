import '../app/shell_model.dart';

/// What a page is and what a person does there, part by part.
typedef PageWords = List<({String title, String words})>;

/// The name a page opened over the frame keeps its explanation under.
String openedPageId(Opened opened) => switch (opened) {
  NothingOpened() => 'nothing',
  WorkOpened() => 'work-item',
  OperationOpened() => 'operation',
  GateOpened() => 'gate',
  EgressOpened() => 'egress',
  BackupsOpened() => 'backups',
  OperationsOpened() => 'operations',
  ReviewOpened() => 'review',
  LogOpened() => 'log',
};

/// The name a machine's section keeps its explanation under.
String machineSectionPageId(MachineSection section) => 'machine-${section.name}';

/// The words of the pages, by the name each is kept under.
const Map<String, PageWords> pageWords = {
  'planning': [
    (
      title: 'What is Planning?',
      words:
          "A project's stories in the steps of its workflow, read from its planning. Open a story to see its issues "
          'and start work on them.',
    ),
  ],
  'cards': [
    (
      title: 'What is My cards & keys?',
      words:
          'Your card says who you are to your machines and your organization; your key signs for you. '
          'Change my key… replaces the key, and your card with it.',
    ),
  ],
  'machine': [
    (
      title: "What is a machine's page?",
      words:
          'One machine: whether it answers, and what it holds at a glance. Where this window holds it, its '
          'sections go further: Tasks, Projects, Vault, Credentials, Agents & providers, Health and Managing this '
          'machine.',
    ),
  ],
  'machine-tasks': [
    (
      title: 'What is Tasks?',
      words:
          "This machine's tasks, running or stopped. Open one to see it and act on it; Running shows the terminals "
          'of its running work.',
    ),
  ],
  'machine-projects': [
    (
      title: 'What is Projects?',
      words: 'The projects on this machine. Open one to see its repositories and saved jobs, and to start work on it.',
    ),
  ],
  'machine-vault': [
    (
      title: 'What is the Vault?',
      words:
          "The entries this machine's vault keeps for its work, never shown, and the devices that open it. Make, "
          'open or shut the vault from here.',
    ),
  ],
  'machine-credentials': [
    (
      title: 'What is Credentials?',
      words:
          "The credentials this machine's work declares: whether each is present where it is kept, and when it "
          'expires where that is known. Add one from here.',
    ),
  ],
  'machine-agents': [
    (
      title: 'What is Agents & providers?',
      words: 'The coding agents installed on this machine, with their versions, and the providers they sign in to.',
    ),
  ],
  'machine-health': [
    (
      title: 'What is Health?',
      words:
          'Whether this machine can run work: each part it checks, and what is missing or not fine. Check it again '
          'from here.',
    ),
  ],
  'machine-managing': [
    (
      title: 'What is Managing this machine?',
      words:
          'Its connection, vault, work and health at a glance, and what can be done with it: check it, read it '
          'again, open or shut its vault, stop Porelo on it, stop everything on it, or clear it of what Porelo put '
          'there.',
    ),
  ],
  'machine-console': [
    (
      title: 'What is SSH Console?',
      words:
          'A shell on this machine in a terminal in this window, as your own account, by the key your agent holds '
          'for it and the host key it was pinned with. Nothing is typed into a form of the window.',
    ),
  ],
  'organization-project': [
    (
      title: "What is an organization's project?",
      words:
          'One project of your organization: whether its pushes need review, its project repository, its '
          'repositories and its members. A Project Admin changes them here, and puts it on a machine or takes it '
          'off.',
    ),
  ],
  'organizations': [
    (
      title: 'What is the Porelo organization?',
      words:
          'Who manages it, its people with their cards, its projects with their members, and its machines. '
          'Porelo asks it whom to trust before anyone gets onto a machine.',
    ),
  ],
  'project': [
    (
      title: "What is a project's page?",
      words:
          'One project on a machine: its repositories, the machines it is on, its saved jobs, the pushes waiting at '
          'the gate, where it may reach on the network, and its room. Start work on it from here.',
    ),
  ],
  'forge': [
    (
      title: "What is a forge's page?",
      words:
          "The repositories you reach on this forge. A repository's menu opens its project, opens it at the "
          'forge, works on it in the Default project, or shows the changes waiting in it.',
    ),
  ],
  'work-item': [
    (
      title: 'What is a piece of work?',
      words: 'One task: what it does, where it runs, and what waits for you. Close it to go back.',
    ),
  ],
  'operation': [
    (
      title: 'What is an operation?',
      words: 'One thing the window did for you, such as setting up a machine: every line it printed, and how it ended.',
    ),
  ],
  'operations': [
    (
      title: 'What is Operations?',
      words: 'What this window ran for you, in this session or on this machine. Open one to read its lines.',
    ),
  ],
  'gate': [
    (
      title: 'What is the gate?',
      words: "The agents' pushes that wait for a person before they leave the machine. Open one to review it.",
    ),
  ],
  'review': [
    (
      title: 'What is a review?',
      words: 'One push waiting at the gate: read its changes, copy the diff, then forward it or drop the request.',
    ),
  ],
  'egress': [
    (
      title: 'What is Egress?',
      words: "Where this machine's work may reach on the network, and what it tried that was not allowed.",
    ),
  ],
  'backups': [
    (
      title: 'What is Backups?',
      words: "The backups recorded of a project's repositories on this machine: restore from one, or remove one.",
    ),
  ],
  'log': [(title: 'What is a log?', words: 'The lines a task writes, as they come. Close it to go back.')],
};

/// The name the Machine Admins page of a machine an organization's card names keeps its explanation under.
const machineAdminsPageId = 'machine-admins';

/// The words of Managing this machine where an organization's card names the machine: its Machine Admins.
const PageWords machineAdminsWords = [
  (
    title: 'What is Machine Admins?',
    words:
        "Who administers this machine for the organization. A Machine Admin names another one here, and makes a "
        'backup key.',
  ),
];
