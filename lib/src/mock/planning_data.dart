import 'dart:convert';

import '../wire/varlink_exception.dart';

/// A fresh board for the interactive mock and scenarios to change independently.
Map<String, dynamic> mockPlanningBoard() => jsonDecode(r'''
{
  "states": [
    {
      "name": "Idea",
      "kind": "WAITING"
    },
    {
      "name": "Accepted",
      "kind": "WAITING"
    },
    {
      "name": "In analysis",
      "kind": "WORKING"
    },
    {
      "name": "Analyzed",
      "kind": "WAITING"
    },
    {
      "name": "Under estimation",
      "kind": "WORKING"
    },
    {
      "name": "Estimated",
      "kind": "WAITING"
    },
    {
      "name": "Backlog",
      "kind": "WAITING"
    },
    {
      "name": "Implementing",
      "kind": "WORKING"
    },
    {
      "name": "Review",
      "kind": "WAITING"
    },
    {
      "name": "Rework",
      "kind": "WAITING"
    },
    {
      "name": "Reworking",
      "kind": "WORKING"
    },
    {
      "name": "Finishing",
      "kind": "WORKING"
    },
    {
      "name": "Finished",
      "kind": "CLOSED"
    },
    {
      "name": "Rejected",
      "kind": "CLOSED"
    }
  ],
  "phases": [
    {
      "name": "Ideas",
      "states": [
        "Idea",
        "Accepted"
      ]
    },
    {
      "name": "Analysis",
      "states": [
        "In analysis",
        "Analyzed"
      ]
    },
    {
      "name": "Estimation",
      "states": [
        "Under estimation",
        "Estimated"
      ]
    },
    {
      "name": "Backlog",
      "states": [
        "Backlog"
      ]
    },
    {
      "name": "Build",
      "states": [
        "Implementing",
        "Reworking",
        "Review",
        "Rework"
      ]
    },
    {
      "name": "Done",
      "states": [
        "Finishing",
        "Finished",
        "Rejected"
      ]
    }
  ],
  "stories": [
    {
      "id": "ST294",
      "title": "Plan the stories on a board in the window",
      "state": "In analysis",
      "priority": "High",
      "gain": "The operator sees every story by state, the most important first, opens a story or an issue, and changes a story’s state by drag and drop, read from and written through a story API whose states are configured, not built in; a state change calls an action API.",
      "test": "Open Planning, find each story in its state’s column sorted by priority, open a story and one of its issues, drag a story to another state and save; the change is in porelo-project’s checkout. Rename a state in the configuration and the board shows it.",
      "link": "https://example.org/stories/ST294",
      "issues": [],
      "work": {
        "tasks": [],
        "mode": "UNATTENDED",
        "agent": "Claude Code",
        "model": "",
        "atWork": true,
        "since": "11:02"
      }
    },
    {
      "id": "ST72",
      "title": "A forge’s calls in a client that knows nothing of Porelo",
      "state": "Under estimation",
      "priority": "Medium",
      "gain": "",
      "test": "",
      "link": "https://example.org/stories/ST72",
      "issues": [
        {
          "id": "PJ74",
          "repository": "porelo-project",
          "state": "Backlog",
          "blockedBy": [],
          "link": "https://example.org/issues/PJ74"
        },
        {
          "id": "FC03",
          "repository": "porelo-forge-clients",
          "state": "Analyzed",
          "blockedBy": [],
          "link": "https://example.org/issues/FC03"
        },
        {
          "id": "FC09",
          "repository": "porelo-forge-clients",
          "state": "Analyzed",
          "blockedBy": [],
          "link": "https://example.org/issues/FC09"
        },
        {
          "id": "FC10",
          "repository": "porelo-forge-clients",
          "state": "Analyzed",
          "blockedBy": [],
          "link": "https://example.org/issues/FC10"
        },
        {
          "id": "FC11",
          "repository": "porelo-forge-clients",
          "state": "Analyzed",
          "blockedBy": [],
          "link": "https://example.org/issues/FC11"
        },
        {
          "id": "FC13",
          "repository": "porelo-forge-clients",
          "state": "Analyzed",
          "blockedBy": [],
          "link": "https://example.org/issues/FC13"
        }
      ],
      "work": {
        "tasks": [],
        "mode": "AGENT",
        "agent": "Claude Code",
        "model": "",
        "atWork": true
      }
    },
    {
      "id": "ST21",
      "title": "No channel file and no hand-over directory any more",
      "state": "Idea",
      "priority": "Highest",
      "gain": "",
      "test": "",
      "link": "https://example.org/stories/ST21",
      "issues": []
    },
    {
      "id": "ST11",
      "title": "porelo-adapters and porelo-ai.github.io each in its own task",
      "state": "Idea",
      "priority": "Highest",
      "gain": "",
      "test": "",
      "link": "https://example.org/stories/ST11"
    },
    {
      "id": "ST13",
      "title": "porelo and porelo-host each in its task, with a way back",
      "state": "Idea",
      "priority": "Highest",
      "gain": "",
      "test": "",
      "link": "https://example.org/stories/ST13"
    },
    {
      "id": "ST28",
      "title": "The setup, move and recovery proven together",
      "state": "Idea",
      "priority": "Highest",
      "gain": "",
      "test": "",
      "link": "https://example.org/stories/ST28",
      "issues": []
    },
    {
      "id": "ST87",
      "title": "Invalid machine inputs refused before renting",
      "state": "Idea",
      "priority": "Medium",
      "gain": "",
      "test": "",
      "link": "https://example.org/stories/ST87"
    },
    {
      "id": "ST182",
      "title": "Review a Bitbucket pull request",
      "state": "Idea",
      "priority": "Low",
      "gain": "",
      "test": "",
      "link": "https://example.org/stories/ST182",
      "issues": []
    },
    {
      "id": "ST114",
      "title": "A vulnerability has a way in and is answered",
      "state": "Accepted",
      "priority": "Medium",
      "gain": "",
      "test": "",
      "link": "https://example.org/stories/ST114"
    },
    {
      "id": "ST111",
      "title": "Install from the intended package source",
      "state": "Accepted",
      "priority": "Medium",
      "gain": "",
      "test": "",
      "link": "https://example.org/stories/ST111"
    },
    {
      "id": "ST144",
      "title": "Understand where a binding setting came from",
      "state": "Accepted",
      "priority": "Low",
      "gain": "",
      "test": "",
      "link": "https://example.org/stories/ST144"
    },
    {
      "id": "ST14",
      "title": "The coordinator reads everything and changes only porelo-project",
      "state": "Analyzed",
      "priority": "Highest",
      "gain": "",
      "test": "",
      "link": "https://example.org/stories/ST14",
      "issues": [
        {
          "id": "PJ58",
          "repository": "porelo-project",
          "state": "Analyzed",
          "blockedBy": [],
          "link": "https://example.org/issues/PJ58"
        }
      ]
    },
    {
      "id": "ST39",
      "title": "A failed delivery named and kept visible",
      "state": "Analyzed",
      "priority": "High",
      "gain": "",
      "test": "",
      "link": "https://example.org/stories/ST39"
    },
    {
      "id": "ST35",
      "title": "Refuse an incompatible protocol and a meaningless option",
      "state": "Analyzed",
      "priority": "High",
      "gain": "",
      "test": "",
      "link": "https://example.org/stories/ST35"
    },
    {
      "id": "ST15",
      "title": "The website builds in its task",
      "state": "Estimated",
      "priority": "Highest",
      "gain": "",
      "test": "",
      "link": "https://example.org/stories/ST15",
      "issues": [
        {
          "id": "SI05",
          "repository": "porelo-ai.github.io",
          "state": "Implementing",
          "blockedBy": [],
          "link": "https://example.org/issues/SI05"
        }
      ]
    },
    {
      "id": "ST106",
      "title": "Make security failures hold the release",
      "state": "Estimated",
      "priority": "Medium",
      "gain": "",
      "test": "",
      "link": "https://example.org/stories/ST106"
    },
    {
      "id": "ST198",
      "title": "Reach a remote machine from Windows",
      "state": "Estimated",
      "priority": "Low",
      "gain": "",
      "test": "",
      "link": "https://example.org/stories/ST198"
    },
    {
      "id": "ST291",
      "text": "# The host tool\n\nThe host runs through a packaged native program.",
      "title": "The host run by a program of its own, built like porelo",
      "state": "Backlog",
      "priority": "Highest",
      "gain": "The host is run by porelo-host, a native program packaged like porelo, instead of scripts copied onto it.",
      "test": "Rent a host, bring it up with porelo-host and run a move on it; every verb answers as the old scripts did.",
      "link": "https://example.org/stories/ST291",
      "issues": [
        {
          "id": "B540",
          "repository": "porelo",
          "state": "Implementing",
          "title": "The host tool as a module of porelo",
          "size": "M",
          "blockedBy": [],
          "link": "https://example.org/issues/B540"
        },
        {
          "id": "B541",
          "text": "# Read the organization\n\nRead the host and task facts from their signed records.",
          "whatMustBeTrue": ["Only confirmed work is published"],
          "findings": [
            {"number": 1, "severity": "BLOCKING", "text": "Check the signature before using the record.", "file": "src/records.dart", "line": 42},
            {"number": 2, "severity": "NOTE", "text": "Keep the explanation beside the result."}
          ],
          "subAgents": [{"name": "Reader", "role": "review", "agent": "Agent", "model": "Model", "brief": "Read the final changes."}],
          "repository": "porelo",
          "state": "Implementing",
          "title": "The host tool reads the organization and a task by its signature",
          "size": "L",
          "blockedBy": [
            "B540"
          ],
          "link": "https://example.org/issues/B541"
        },
        {
          "id": "B542",
          "repository": "porelo",
          "state": "Backlog",
          "blockedBy": [],
          "link": "https://example.org/issues/B542"
        },
        {
          "id": "B543",
          "repository": "porelo",
          "state": "Backlog",
          "blockedBy": [],
          "link": "https://example.org/issues/B543"
        },
        {
          "id": "B544",
          "repository": "porelo",
          "state": "Backlog",
          "blockedBy": [],
          "link": "https://example.org/issues/B544"
        },
        {
          "id": "B545",
          "repository": "porelo",
          "state": "Backlog",
          "blockedBy": [],
          "link": "https://example.org/issues/B545"
        },
        {
          "id": "B546",
          "repository": "porelo",
          "state": "Backlog",
          "blockedBy": [],
          "link": "https://example.org/issues/B546"
        },
        {
          "id": "B547",
          "repository": "porelo",
          "state": "Backlog",
          "blockedBy": [],
          "link": "https://example.org/issues/B547"
        },
        {
          "id": "B548",
          "repository": "porelo",
          "state": "Backlog",
          "blockedBy": [],
          "link": "https://example.org/issues/B548"
        },
        {
          "id": "B549",
          "repository": "porelo",
          "state": "Backlog",
          "blockedBy": [],
          "link": "https://example.org/issues/B549"
        },
        {
          "id": "B550",
          "repository": "porelo",
          "state": "Backlog",
          "blockedBy": [],
          "link": "https://example.org/issues/B550"
        },
        {
          "id": "B551",
          "repository": "porelo",
          "state": "Backlog",
          "blockedBy": [],
          "link": "https://example.org/issues/B551"
        },
        {
          "id": "B552",
          "repository": "porelo",
          "state": "Backlog",
          "blockedBy": [],
          "link": "https://example.org/issues/B552"
        },
        {
          "id": "HO156",
          "repository": "porelo-host",
          "state": "Backlog",
          "blockedBy": [],
          "link": "https://example.org/issues/HO156"
        },
        {
          "id": "HO157",
          "repository": "porelo-host",
          "state": "Backlog",
          "blockedBy": [],
          "link": "https://example.org/issues/HO157"
        }
      ]
    },
    {
      "id": "ST292",
      "title": "A whole move rehearsed by the agents on a rented server",
      "state": "Backlog",
      "priority": "Highest",
      "gain": "The agents rehearse a whole move on a rented server before the operator’s own test, so most problems are found earlier.",
      "test": "Rent a server and let the agents run the rehearsal; the report names every scenario OK, and the window and the room agree with the host.",
      "link": "https://example.org/stories/ST292",
      "issues": [
        {
          "id": "B553",
          "repository": "porelo",
          "state": "Implementing",
          "title": "A move runs without a terminal for a rehearsal",
          "size": "M",
          "blockedBy": [],
          "link": "https://example.org/issues/B553"
        },
        {
          "id": "B554",
          "repository": "porelo",
          "state": "Implementing",
          "title": "A forge token’s reach checked against what a move needs",
          "size": "S",
          "blockedBy": [],
          "link": "https://example.org/issues/B554"
        },
        {
          "id": "F444",
          "repository": "porelo-frontend",
          "state": "Implementing",
          "title": "A move driven through the window against a rented host",
          "size": "M",
          "blockedBy": [],
          "link": "https://example.org/issues/F444"
        },
        {
          "id": "F445",
          "repository": "porelo-frontend",
          "state": "Implementing",
          "title": "What a rehearsal cannot drive in the window, stood in for",
          "size": "S",
          "blockedBy": [
            "F444"
          ],
          "link": "https://example.org/issues/F445"
        },
        {
          "id": "HO158",
          "repository": "porelo-host",
          "state": "Implementing",
          "title": "A move rehearsed on a rented server",
          "size": "L",
          "blockedBy": [],
          "link": "https://example.org/issues/HO158"
        },
        {
          "id": "MX89",
          "repository": "porelo-message-matrix",
          "state": "Implementing",
          "title": "A test person signs in through the gate unattended",
          "size": "S",
          "blockedBy": [],
          "link": "https://example.org/issues/MX89"
        },
        {
          "id": "MX90",
          "repository": "porelo-message-matrix",
          "state": "Implementing",
          "title": "The room’s scenarios are rehearsed on a host",
          "size": "S",
          "blockedBy": [
            "MX89"
          ],
          "link": "https://example.org/issues/MX90"
        },
        {
          "id": "MX91",
          "repository": "porelo-message-matrix",
          "state": "Implementing",
          "title": "The rehearsal says a wake was answered",
          "size": "XS",
          "blockedBy": [
            "MX89"
          ],
          "link": "https://example.org/issues/MX91"
        }
      ]
    },
    {
      "id": "ST293",
      "title": "Every agent works in a Porelo task, moved one at a time",
      "state": "Backlog",
      "priority": "Highest",
      "gain": "",
      "test": "",
      "link": "https://example.org/stories/ST293",
      "issues": []
    },
    {
      "id": "ST23",
      "title": "The room and the usage records outlive the host",
      "state": "Backlog",
      "priority": "Highest",
      "gain": "",
      "test": "",
      "link": "https://example.org/stories/ST23",
      "issues": [
        {
          "id": "MX24",
          "repository": "porelo-message-matrix",
          "state": "Review",
          "blockedBy": [],
          "link": "https://example.org/issues/MX24"
        },
        {
          "id": "MX36",
          "repository": "porelo-message-matrix",
          "state": "Finished",
          "blockedBy": [],
          "link": "https://example.org/issues/MX36"
        },
        {
          "id": "MX39",
          "repository": "porelo-message-matrix",
          "state": "Finished",
          "blockedBy": [],
          "link": "https://example.org/issues/MX39"
        },
        {
          "id": "HO07",
          "repository": "porelo-host",
          "state": "Backlog",
          "blockedBy": [],
          "link": "https://example.org/issues/HO07"
        },
        {
          "id": "B231",
          "repository": "porelo",
          "state": "Backlog",
          "blockedBy": [],
          "link": "https://example.org/issues/B231"
        }
      ]
    },
    {
      "id": "ST6",
      "title": "porelo-agy and porelo-codex each in its own task",
      "state": "Backlog",
      "priority": "Highest",
      "gain": "",
      "test": "",
      "link": "https://example.org/stories/ST6"
    },
    {
      "id": "ST27",
      "title": "Every workflow runs on the local forge as on the central one",
      "state": "Implementing",
      "priority": "Highest",
      "gain": "",
      "test": "",
      "link": "https://example.org/stories/ST27",
      "issues": [
        {
          "id": "IJ14",
          "repository": "porelo-intellij",
          "state": "Finished",
          "blockedBy": [],
          "link": "https://example.org/issues/IJ14"
        }
      ],
      "work": {
        "tasks": [
          "build-one",
          "build-two"
        ],
        "mode": "UNATTENDED",
        "agent": "",
        "model": "",
        "atWork": true,
        "coordinator": "Coordinator",
        "since": "09:10"
      }
    },
    {
      "id": "ST12",
      "title": "The release and pipeline tools the move rests on",
      "state": "Implementing",
      "priority": "Highest",
      "gain": "",
      "test": "",
      "link": "https://example.org/stories/ST12",
      "issues": [
        {
          "id": "BT35",
          "repository": "porelo-buildtools",
          "state": "Finished",
          "blockedBy": [],
          "link": "https://example.org/issues/BT35"
        },
        {
          "id": "BT36",
          "repository": "porelo-buildtools",
          "state": "Review",
          "blockedBy": [],
          "link": "https://example.org/issues/BT36"
        },
        {
          "id": "BT38",
          "repository": "porelo-buildtools",
          "state": "Review",
          "blockedBy": [],
          "link": "https://example.org/issues/BT38"
        },
        {
          "id": "BT43",
          "repository": "porelo-buildtools",
          "state": "Implementing",
          "blockedBy": [],
          "link": "https://example.org/issues/BT43"
        },
        {
          "id": "BT44",
          "repository": "porelo-buildtools",
          "state": "Implementing",
          "blockedBy": [],
          "link": "https://example.org/issues/BT44"
        },
        {
          "id": "BT45",
          "repository": "porelo-buildtools",
          "state": "Implementing",
          "blockedBy": [],
          "link": "https://example.org/issues/BT45"
        },
        {
          "id": "BT46",
          "repository": "porelo-buildtools",
          "state": "Implementing",
          "blockedBy": [],
          "link": "https://example.org/issues/BT46"
        }
      ],
      "work": {
        "tasks": [
          "build-one",
          "build-two"
        ],
        "mode": "UNATTENDED",
        "agent": "",
        "model": "",
        "atWork": true,
        "coordinator": "Coordinator",
        "since": "09:10"
      }
    },
    {
      "id": "ST5",
      "title": "porelo-pi, porelo-omp and porelo-claude-code each in its own task",
      "state": "Implementing",
      "priority": "Highest",
      "gain": "",
      "test": "",
      "link": "https://example.org/stories/ST5",
      "issues": [
        {
          "id": "PI43",
          "repository": "porelo-pi",
          "state": "Implementing",
          "blockedBy": [],
          "link": "https://example.org/issues/PI43"
        },
        {
          "id": "OM44",
          "repository": "porelo-omp",
          "state": "Backlog",
          "blockedBy": [],
          "link": "https://example.org/issues/OM44"
        },
        {
          "id": "CC45",
          "repository": "porelo-claude-code",
          "state": "Implementing",
          "blockedBy": [],
          "link": "https://example.org/issues/CC45"
        },
        {
          "id": "PI39",
          "repository": "porelo-pi",
          "state": "Review",
          "blockedBy": [],
          "link": "https://example.org/issues/PI39"
        },
        {
          "id": "OM36",
          "repository": "porelo-omp",
          "state": "Review",
          "blockedBy": [],
          "link": "https://example.org/issues/OM36"
        },
        {
          "id": "CC39",
          "repository": "porelo-claude-code",
          "state": "Review",
          "blockedBy": [],
          "link": "https://example.org/issues/CC39"
        }
      ],
      "work": {
        "tasks": [
          "build-one",
          "build-two"
        ],
        "mode": "UNATTENDED",
        "agent": "",
        "model": "",
        "atWork": true,
        "coordinator": "Coordinator",
        "since": "09:10"
      }
    },
    {
      "id": "ST193",
      "title": "Choose drive areas for each host",
      "state": "Implementing",
      "priority": "Low",
      "gain": "",
      "test": "",
      "link": "https://example.org/stories/ST193",
      "issues": [
        {
          "id": "PJ106",
          "repository": "porelo-project",
          "state": "Backlog",
          "blockedBy": [],
          "link": "https://example.org/issues/PJ106"
        }
      ],
      "work": {
        "tasks": [
          "build-one",
          "build-two"
        ],
        "mode": "UNATTENDED",
        "agent": "",
        "model": "",
        "atWork": true,
        "coordinator": "Coordinator",
        "since": "09:10"
      }
    },
    {
      "id": "ST127",
      "title": "Keep container limits on large hosts",
      "state": "Implementing",
      "priority": "Low",
      "gain": "",
      "test": "",
      "link": "https://example.org/stories/ST127",
      "issues": [],
      "work": {
        "tasks": [
          "build-one",
          "build-two"
        ],
        "mode": "UNATTENDED",
        "agent": "",
        "model": "",
        "atWork": true,
        "coordinator": "Coordinator",
        "since": "09:10"
      }
    },
    {
      "id": "ST1",
      "title": "Builds on the host’s forge resolve snapshots with a read-only token",
      "state": "Review",
      "priority": "Highest",
      "gain": "",
      "test": "",
      "link": "https://example.org/stories/ST1",
      "issues": [
        {
          "id": "BT42",
          "repository": "porelo-buildtools",
          "state": "Review",
          "blockedBy": [],
          "link": "https://example.org/issues/BT42"
        },
        {
          "id": "BT39",
          "repository": "porelo-buildtools",
          "state": "Review",
          "blockedBy": [],
          "link": "https://example.org/issues/BT39"
        },
        {
          "id": "HO52",
          "repository": "porelo-host",
          "state": "Review",
          "blockedBy": [],
          "link": "https://example.org/issues/HO52"
        },
        {
          "id": "SL36",
          "repository": "porelo-message-sluice",
          "state": "Review",
          "blockedBy": [],
          "link": "https://example.org/issues/SL36"
        },
        {
          "id": "BT40",
          "repository": "porelo-buildtools",
          "state": "Finished",
          "blockedBy": [],
          "link": "https://example.org/issues/BT40"
        },
        {
          "id": "BT41",
          "repository": "porelo-buildtools",
          "state": "Finished",
          "blockedBy": [],
          "link": "https://example.org/issues/BT41"
        },
        {
          "id": "HO53",
          "repository": "porelo-host",
          "state": "Finished",
          "blockedBy": [],
          "link": "https://example.org/issues/HO53"
        }
      ]
    },
    {
      "id": "ST2",
      "title": "porelo-message-sluice works wholly in its task",
      "state": "Review",
      "priority": "Highest",
      "gain": "",
      "test": "",
      "link": "https://example.org/stories/ST2",
      "issues": [
        {
          "id": "SL35",
          "repository": "porelo-message-sluice",
          "state": "Review",
          "blockedBy": [],
          "link": "https://example.org/issues/SL35"
        }
      ]
    },
    {
      "id": "ST3",
      "title": "porelo’s Build on the host’s Forgejo",
      "state": "Review",
      "priority": "Highest",
      "gain": "",
      "test": "",
      "link": "https://example.org/stories/ST3",
      "issues": [
        {
          "id": "B306",
          "repository": "porelo",
          "state": "Review",
          "blockedBy": [],
          "link": "https://example.org/issues/B306"
        }
      ]
    },
    {
      "id": "ST10",
      "title": "Test machines by kind from the VM pool",
      "state": "Review",
      "priority": "Highest",
      "gain": "",
      "test": "",
      "link": "https://example.org/stories/ST10",
      "issues": [
        {
          "id": "HO12",
          "repository": "porelo-host",
          "state": "Review",
          "blockedBy": [],
          "link": "https://example.org/issues/HO12"
        },
        {
          "id": "BT24",
          "repository": "porelo-buildtools",
          "state": "Review",
          "blockedBy": [],
          "link": "https://example.org/issues/BT24"
        },
        {
          "id": "BT25",
          "repository": "porelo-buildtools",
          "state": "Review",
          "blockedBy": [],
          "link": "https://example.org/issues/BT25"
        }
      ]
    },
    {
      "id": "ST264",
      "title": "A host prepared with no project or person",
      "state": "Finished",
      "priority": "Highest",
      "gain": "",
      "test": "",
      "link": "https://example.org/stories/ST264"
    },
    {
      "id": "ST268",
      "title": "Each person’s one key and card, kept in the registry",
      "state": "Finished",
      "priority": "Highest",
      "gain": "",
      "test": "",
      "link": "https://example.org/stories/ST268"
    },
    {
      "id": "ST243",
      "title": "Both adapters pass one contract suite",
      "state": "Finished",
      "priority": "Highest",
      "gain": "",
      "test": "",
      "link": "https://example.org/stories/ST243",
      "issues": [
        {
          "id": "PJ62",
          "repository": "porelo-project",
          "state": "Finished",
          "blockedBy": [],
          "link": "https://example.org/issues/PJ62"
        },
        {
          "id": "GH18",
          "repository": "porelo-adapters",
          "state": "Finished",
          "blockedBy": [],
          "link": "https://example.org/issues/GH18"
        }
      ]
    }
  ],
  "revision": "design-1"
}
''') as Map<String, dynamic>;

/// Finds exactly one reported story for stand-in detail reads.
Map<String, dynamic>? mockPlanningStory(Map<String, dynamic> board, Object? id) {
  final stories = board['stories'];
  if (id is! String || id.isEmpty || stories is! List) return null;
  return stories.whereType<Map<String, dynamic>>().where((story) => story['id'] == id).firstOrNull;
}

/// Finds an issue and supplies its owning story from the stand-in store.
Map<String, dynamic>? mockPlanningIssue(Map<String, dynamic> board, Object? id) {
  final stories = board['stories'];
  if (id is! String || id.isEmpty || stories is! List) return null;
  for (final story in stories.whereType<Map<String, dynamic>>()) {
    final issues = story['issues'];
    if (issues is! List) continue;
    final issue = issues.whereType<Map<String, dynamic>>().where((issue) => issue['id'] == id).firstOrNull;
    if (issue != null) return {'story': story['id'], ...issue};
  }
  return null;
}

/// Validates the entire move batch before replacing any of the stand-in store's data.
Map<String, dynamic> mockMoveIssues(Map<String, dynamic> board, Object? moves, Object? revision) {
  Never refuse(String name, Map<String, dynamic> parameters) =>
      throw VarlinkException('org.fuin.porelo.Tasks1.$name', parameters);
  if (revision is! String || revision != board['revision']) {
    refuse('StaleRevision', {'revision': board['revision'] is String ? board['revision'] : ''});
  }
  final next = jsonDecode(jsonEncode(board)) as Map<String, dynamic>;
  final states = next['states'] is List
      ? (next['states'] as List).whereType<Map<String, dynamic>>().toList()
      : <Map<String, dynamic>>[];
  final issues = <Map<String, dynamic>>[
    if (next['stories'] is List)
      for (final story in (next['stories'] as List).whereType<Map<String, dynamic>>())
        if (story['issues'] is List) ...(story['issues'] as List).whereType<Map<String, dynamic>>(),
  ];
  if (moves is! List) {
    refuse('MoveNotAllowed', {'item': '', 'from': '', 'to': '', 'reason': 'The issue moves must be a list.'});
  }
  final changes = <(Map<String, dynamic>, String)>[];
  final seen = <String>{};
  for (final value in moves) {
    final map = value is Map<String, dynamic> ? value : <String, dynamic>{};
    final item = map['issue'] is String ? map['issue'] as String : '';
    final to = map['to'] is String ? map['to'] as String : '';
    final issue = issues.where((issue) => issue['id'] == item).firstOrNull;
    final from = issue?['state'] is String ? issue!['state'] as String : '';
    if (item.isEmpty || to.isEmpty || issue == null || !seen.add(item)) {
      refuse('MoveNotAllowed', {
        'item': item,
        'from': from,
        'to': to,
        'reason': 'Each move must name one existing issue and one destination, without duplicates.',
      });
    }
    final state = states.where((state) => state['name'] == to).firstOrNull;
    if (state?['kind'] == 'WORKING') refuse('EnteredOnlyByWork', {'item': item, 'to': to});
    if (state == null || !{'WAITING', 'CLOSED'}.contains(state['kind'])) {
      refuse('StateNotAllowed', {
        'item': item,
        'from': from,
        'to': to,
        'reason': 'The destination is not a configured waiting or closed state.',
      });
    }
    changes.add((issue, to));
  }
  for (final (issue, to) in changes) {
    issue['state'] = to;
  }
  next['revision'] = '$revision:moved';
  return next;
}

/// A refusal produced by the stateful planning stand-in.
class MockPlanningRefusal implements Exception {
  /// Keeps the refusal detail returned by the stand-in.
  const MockPlanningRefusal(this.detail);

  /// The verbatim reason this call was refused.
  final String detail;
}

/// The same daemon decisions behind the socket mock and widget FakeBackend.
class MockStoryWork {
  /// Uses the same authoritative board reader and watch publisher as planning.
  MockStoryWork(this.boardFor, this.changed);

  /// Reads the authoritative board for one project.
  final Map<String, dynamic> Function(String) boardFor;

  /// Publishes a complete replacement on that project’s watch.
  final void Function(String, Map<String, dynamic>) changed;

  /// Copies every method and parameter received for inspection by tests.
  final List<(String, Map<String, dynamic>)> calls = [];

  /// Explicit proposals supplied by scenarios, indexed by story.
  final Map<String, Map<String, dynamic>> proposals = {};

  /// The last findings returned by the machine.
  final Map<String, List<Map<String, dynamic>>> findings = {};

  /// Explicit GetStoryWork answers supplied by scenarios, indexed by story.
  final Map<String, Map<String, dynamic>> statuses = {};

  /// The daemon detail returned instead of processing a call, when set.
  String? refusal;

  /// Whether calls answer without publishing the replacement board, to exercise echo waits.
  bool deferEcho = false;
  int _revision = 0;

  /// Processes one planning call against the current board and refuses stale decisions.
  Map<String, dynamic> call(String method, Map<String, dynamic> parameters) {
    calls.add((method, jsonDecode(jsonEncode(parameters)) as Map<String, dynamic>));
    if (refusal case final detail?) throw MockPlanningRefusal(detail);
    final project = parameters['project'];
    if (project is! String || project.isEmpty || project.contains('/') || project.contains('\\')) {
      throw const MockPlanningRefusal('A project name is required.');
    }
    final board = jsonDecode(jsonEncode(boardFor(project))) as Map<String, dynamic>;
    final stories = (board['stories'] as List).cast<Map<String, dynamic>>();
    final story = stories.where((story) => story['id'] == parameters['story']).firstOrNull;
    final issues = stories.expand((story) => (story['issues'] as List? ?? []).cast<Map<String, dynamic>>());
    final issue = issues.where((issue) => issue['id'] == parameters['issue']).firstOrNull;
    if (method == 'GetIssue') {
      if (issue == null) throw const MockPlanningRefusal('The issue is not on this board.');
      final detail = mockPlanningIssue(board, parameters['issue'])!;
      return {
        ...detail,
        'issue': detail,
        'text': detail['text'],
        'whatMustBeTrue': detail['whatMustBeTrue'],
        'findings': findings[issue['id']] ?? detail['findings'] ?? <Map<String, dynamic>>[],
        'subAgents': detail['subAgents'],
      };
    }
    if (method == 'ResolveIssueReading') {
      if (parameters['revision'] != board['revision']) {
        throw const MockPlanningRefusal('The planning revision changed.');
      }
      if (issue == null || issue['readingStopped'] != true || issue['rounds'] != parameters['round']) {
        throw const MockPlanningRefusal('This reading is no longer stopped at that round.');
      }
      final choice = parameters['choice'];
      if (!['REVIEW_ANYWAY', 'ONE_MORE_ROUND', 'REWORK'].contains(choice)) {
        throw const MockPlanningRefusal('Unknown reading choice.');
      }
      if (choice == 'REWORK' &&
          (parameters['comment'] is! String || (parameters['comment'] as String).trim().isEmpty)) {
        throw const MockPlanningRefusal('Rework needs a comment.');
      }
      issue['readingStopped'] = false;
      if (choice == 'REVIEW_ANYWAY') issue['state'] = 'Review';
      if (choice == 'ONE_MORE_ROUND') {
        issue['roundsMost'] = (issue['roundsMost'] as int? ?? parameters['round'] as int) + 1;
      }
      if (choice == 'REWORK') issue['state'] = 'Reworking';
      board['revision'] = 'work-${++_revision}';
      if (!deferEcho) changed(project, board);
      return {'revision': board['revision']};
    }
    if (story == null) throw const MockPlanningRefusal('The story is not on this board.');
    if (method == 'GetStoryWork') return statuses[story['id']] ?? {'work': story['work'], 'ended': story['ended']};
    if (method == 'ProposeStoryWork') {
      final supplied = proposals[story['id']];
      if (supplied != null) return supplied;
      final repositories = (story['issues'] as List? ?? [])
          .cast<Map<String, dynamic>>()
          .map((issue) => issue['repository'] as String)
          .toSet();
      if (repositories.isEmpty) repositories.add('porelo-project');
      return {
        'modes': ['UNATTENDED', 'AGENT'],
        'readingRounds': 3,
        'startLabel': parameters['to'] == 'In analysis' ? 'Start the analysis' : 'Start ${repositories.length} tasks',
        'modeDetails': [
          {
            'mode': 'UNATTENDED',
            'words': 'The agents work alone in their tasks. You see their progress on the board.',
            'workOrder':
                'Work on story ${story['id']} alone. Read its gain and test and finish the work for ${parameters['to']}.',
          },
          {
            'mode': 'AGENT',
            'words': 'You work with the agents in the coordinator’s terminal, or the story’s one task.',
            'workOrder': 'Work on story ${story['id']} with the person in the terminal. Ask before deciding.',
          },
        ],
        'repositories': [
          for (final repo in repositories)
            {
              'repository': repo,
              'task': '${(story['id'] as String).toLowerCase()}-$repo',
              'agent': 'codex',
              'model': 'proposed-model',
              'modelHint': 'Proposed from this repository’s settings for ${parameters['to']}.',
              'workOrder':
                  'Read the index and build the issues of ${story['id']} in $repo. Follow the project’s review and build rules.',
              'issues': [
                for (final issue in (story['issues'] as List).cast<Map<String, dynamic>>())
                  if (issue['repository'] == repo) issue['id'],
              ],
              'subAgents': [
                {
                  'name': 'builder',
                  'role': 'builder',
                  'agent': 'codex',
                  'model': 'proposed-model',
                  'brief': 'Build the issues in this repository.',
                },
                {
                  'name': 'reader',
                  'role': 'reader',
                  'agent': 'claude-code',
                  'model': 'reader-model',
                  'brief': 'Read the final changes.',
                },
              ],
            },
        ],
        if (repositories.length > 1)
          'coordinator': {
            'agent': 'codex',
            'model': 'coordinator-model',
            'sentence':
                stories.any(
                  (each) =>
                      each['work'] is Map &&
                      (each['work'] as Map)['atWork'] == true &&
                      (each['work'] as Map)['coordinator'] != null,
                )
                ? 'The project’s coordinator is running. It is told to oversee this story as well; no second coordinator is started.'
                : 'The project’s coordinator is started to oversee this story.',
          },
        'issues': [
          for (final issue in (story['issues'] as List? ?? []).cast<Map<String, dynamic>>())
            {'id': issue['id'], 'repository': issue['repository']},
        ],
      };
    }
    if (method == 'StopStoryWork') {
      if (story['work'] is! Map || (story['work'] as Map)['atWork'] != true) {
        throw const MockPlanningRefusal('No story work is running.');
      }
      story['work'] = {...story['work'] as Map<String, dynamic>, 'atWork': false};
      board['revision'] = 'work-${++_revision}';
      if (!deferEcho) changed(project, board);
      return {};
    }
    if (method != 'StartStoryWork') throw const MockPlanningRefusal('Unknown planning method.');
    if (parameters['revision'] != board['revision']) throw const MockPlanningRefusal('The planning revision changed.');
    final state = (board['states'] as List)
        .cast<Map<String, dynamic>>()
        .where((state) => state['name'] == parameters['to'])
        .firstOrNull;
    if (state?['kind'] != 'WORKING') throw const MockPlanningRefusal('The target is not a working state.');
    if (story['work'] is Map && (story['work'] as Map)['atWork'] == true) {
      throw const MockPlanningRefusal('Work is already running.');
    }
    final proposal =
        proposals[story['id']] ??
        call('ProposeStoryWork', {'project': project, 'story': story['id'], 'to': parameters['to']});
    if (!(proposal['modes'] as List).contains(parameters['mode'])) {
      throw const MockPlanningRefusal('The project does not allow that mode.');
    }
    final subs = (parameters['subAgents'] as List).cast<Map<String, dynamic>>();
    if (subs.any((sub) => sub['choice'] != 'KEEP') &&
        (parameters['comment'] is! String || (parameters['comment'] as String).trim().isEmpty)) {
      throw const MockPlanningRefusal('A changed or dropped participant needs a comment.');
    }
    final selected = (parameters['repositories'] as List? ?? []).cast<Map<String, dynamic>>();
    final proposedRepos = (proposal['repositories'] as List).cast<Map<String, dynamic>>();
    if (selected.length != proposedRepos.length ||
        selected.any(
          (repo) =>
              !proposedRepos.any((proposed) => proposed['repository'] == repo['repository']) ||
              repo['agent'] is! String ||
              (repo['agent'] as String).isEmpty ||
              repo['model'] is! String ||
              (repo['model'] as String).isEmpty,
        )) {
      throw const MockPlanningRefusal('Choose the main agent and model for every repository.');
    }
    story['state'] = parameters['to'];
    story['ended'] = null;
    final repos = (proposal['repositories'] as List).cast<Map<String, dynamic>>();
    story['work'] = {
      'tasks': [for (final repo in repos) repo['task']],
      if (proposal['coordinator'] != null) 'coordinator': 'coordinator',
      'mode': parameters['mode'],
      'agent': selected.first['agent'],
      'model': selected.first['model'],
      'atWork': true,
    };
    board['revision'] = 'work-${++_revision}';
    if (!deferEcho) changed(project, board);
    Map<String, dynamic> taskFor(String name, String repository, String agent, String model) => {
      'name': name,
      'task': name,
      'project': project,
      'repository': repository,
      'agent': agent,
      'model': model,
      'running': true,
      'state': 'Up',
      'mode': parameters['mode'] == 'AGENT' ? 'SHELL' : 'UNATTENDED',
      'activity': 'WORKING',
    };
    return {
      'started': true,
      'revision': board['revision'],
      'tasks': [
        for (final repo in repos)
          taskFor(
            repo['task'] as String,
            repo['repository'] as String,
            selected.firstWhere((each) => each['repository'] == repo['repository'])['agent'] as String,
            selected.firstWhere((each) => each['repository'] == repo['repository'])['model'] as String,
          ),
      ],
      if (proposal['coordinator'] case final Map<String, dynamic> coordinator)
        'coordinator': taskFor('coordinator', '', coordinator['agent'] as String, coordinator['model'] as String),
    };
  }
}
