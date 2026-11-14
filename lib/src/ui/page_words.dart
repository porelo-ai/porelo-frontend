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

/// The words of the pages that draw them on their own head, by the name each is kept under.
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
          'My key and card… opens them.',
    ),
  ],
  'machine': [
    (
      title: "What is a machine's page?",
      words:
          'One machine: whether it answers and what it holds. Its sections go on: its tasks, projects, vault, '
          'credentials, agents, health and how it is managed.',
    ),
  ],
  'machine-tasks': [
    (
      title: 'What is Tasks?',
      words:
          'The work on this machine: running, waiting for a person, or stopped. Open a task to see it and act on it.',
    ),
  ],
  'machine-projects': [
    (
      title: 'What is Projects?',
      words: "The projects on this machine. Open one to see its repositories and jobs, and to start work on it.",
    ),
  ],
  'machine-vault': [
    (
      title: 'What is the Vault?',
      words: "What this machine keeps sealed for its work, and the devices that may open it.",
    ),
  ],
  'machine-credentials': [
    (
      title: 'What is Credentials?',
      words: "The tokens and keys this machine's work signs in with, and whether each still holds.",
    ),
  ],
  'machine-agents': [
    (
      title: 'What is Agents & providers?',
      words: 'The coding agents this machine can run and the providers they reach, with what stands in their way.',
    ),
  ],
  'machine-health': [
    (
      title: 'What is Health?',
      words: "Checks of this machine's parts: whether each answers, and what stands in the way of work.",
    ),
  ],
  'machine-managing': [
    (
      title: 'What is Managing this machine?',
      words: 'Who manages this machine and how it is kept: its connection, its updates, and taking it off.',
    ),
  ],
  'project': [
    (
      title: "What is a project's page?",
      words:
          'One project on a machine: its repositories, its jobs, who reviews what it pushes and whom it may talk '
          'to. Start work on it from here.',
    ),
  ],
  'forge': [
    (
      title: "What is a forge's page?",
      words: "The repositories you reach on this forge. A repository's menu makes it a project.",
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
    (title: 'What is Operations?', words: 'What the window did for you, newest first. Open one to read its lines.'),
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
      words: 'One push waiting at the gate: read its changes, then approve it to let it out or reject it.',
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
      words: "Copies of this machine's mirror of its repositories: look at one, restore from it, or remove it.",
    ),
  ],
  'log': [(title: 'What is a log?', words: 'The lines a task writes, as they come. Close it to go back.')],
};
