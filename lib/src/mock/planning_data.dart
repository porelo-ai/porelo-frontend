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
