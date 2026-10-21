# CR-05: ECM duration changes with tick cadence

The shared ECM field and player announcement control previously counted 32 simulation calls while retaliation orders expired after three seconds. With 0.1-second ticks an early confirmed return-fire order could expire during the field. Supported fields need one elapsed simulation-time authority, including existing enemy and legacy callers.

Keep the original 32 frames at a documented 60 Hz reference cadence (32/60 seconds), retain activation identities and ownership, and emit one destruction outcome. Menus and pause must not advance the field. Matched-duration regressions must cover 60 Hz, 30 Hz and 0.1-second partitions and once-only retaliation. Implementation and validation: [handoff](PR-CR-05-ecm-time.md).
