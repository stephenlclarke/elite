# Observe a failed original courier approach without changing flight

A failure-only observer now records the final snapshot immediately after the original approach loop and before its unchanged required docking assertion. It writes only to the existing isolated validation evidence directory: full actual Commander and world (including people, law, physical bodies, poses and resources), selected target, autopilot, player velocity, original loop counters, collision observation and current messages. A concise health/time/range summary is also printed. Capture failures are reported and cannot replace the original test failure.

These diagnostic bytes are never game saves or restore inputs. No runtime command, save, simulation tick, control, law, health, NPC, station, celestial, oracle or budget changes. No fatal-hit attribution is claimed; retained law windows are not a per-hit damage history. The one original method still contains all six rows, with actual physical travel for its first two rows. Whole-file inverse recovery confirms only this observer and its failure-only call were added.

Validation is cold source formatting/lint/Markdown and scope checks only. No compiler, test, native or renderer run has occurred for this leaf. Source review and one separately authorized necessary diagnostic execution remain pending.
