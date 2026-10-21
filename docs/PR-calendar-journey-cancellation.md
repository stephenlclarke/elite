# Preserve cancellation and startup clock continuity

Navigation cancellation, manual system selection and a confirmed replacement route now clear the existing calendar journey alongside the countdown. The existing cancellation helper preserves fuel, charges and operation history.

Continuing from the title restores the backed-up frame time and clears that backup before entering the status screen. Startup backs up time for every actual retained feature covered by `requiresScriptDurability`, including calendar and contract saves. Fresh game-over initialization is unchanged.

The original three cancellation cases and saved-time assertion remain. Added checks cover a real fitted navigation computer and confirmed route replacement, unchanged fuel/operation/charge, unchanged commander during title continuation, and the next frame's advancing event time. Formatting, strict formatting lint and diff checks pass. Compilation and execution are pending the orchestrator's isolated validation; no full CI or release acceptance is claimed.

The separately diagnosed legacy prepared-actor identity regression remains open. This change does not alter actor admission guards or legacy saved identities. Related [issue](ISSUE-calendar-journey-cancellation.md).
