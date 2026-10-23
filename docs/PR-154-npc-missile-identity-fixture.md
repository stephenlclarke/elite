# Track exact NPC missile and launcher identities

## Motivation

[Issue154](https://github.com/stephenlclarke/elite/issues/154) identifies a positional test oracle invalidated by legitimate native station population after the launcher is removed.

## Implementation

Capture the original launcher and missile physical identities, remove only that launcher and resolve the same missile after flight. Keep separate finite-ammunition/second-refusal assertions and all original impact, damage, no-kill and cash checks. Tests only; no launcher, projectile, station or ownership policy changes.

## Validation

Formatting and diff hygiene pass. The unchanged original method is part of the current bounded151/154 focused selection. Execution and independent actual-source/result review are pending. Preserve the original failed result and incomplete XML; no aggregate pass is inferred.

## Compatibility and remaining limits

No save schema or player behavior changes. The mission crash remains separate151 and historical144 origins remain unknown. Full VM/quality/native M01/release remain separate.
