# Add Command-P pause and resume

The Game menu provides Pause / Resume with Command-P. It queues an actor command, preserving plain P for docking-computer disengagement. The README, contextual guide and pause overlay show the available shortcut. Existing full-keyboard COPY/End input remains accepted for compatibility.

Native tests validate the menu's command modifier and process both pause and resume through the running window loop. Core tests verify that pause freezes simulation and works during mission messages. The app is rebuilt for native keyboard validation.

Request: [ISSUE-macbook-pause.md](ISSUE-macbook-pause.md).
