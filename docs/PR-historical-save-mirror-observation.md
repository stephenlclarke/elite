# Capture actual historical save mirror changes without changing the oracle

The existing format-21 migration method now captures its actual current versioned readback once before the same complete Commander assertion. A supplemental report records typed inventory, history, mining, calendar, flight, NPC, salvage, cargo and laser getter equality alongside all encoded top-level field deltas. Encoded array ordering is diagnostic noise where typed equality remains true; it never becomes the comparison oracle.

The expected Commander, actual save/load sequence and remaining full equality/byte checks are unchanged. Only isolated fixture evidence is written, with no production logging or user-file access. Source parsing, strict formatting, scoped Markdown lint and whitespace checks precede frozen-source review and one existing-method diagnostic under the original 600-second limit and default TSan concurrency. No source cause, repair or passing result is claimed by this source packet. Other 318 passing scopes remain retained.

[ISSUE-historical-save-mirror-observation.md](ISSUE-historical-save-mirror-observation.md).
