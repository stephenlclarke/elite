# Observe attained Crimbo movement after the actual actor step

## Problem

The native adapter prepares a transient motion sample, but only the actor knows whether a genuine physical step completed, native entry was attempted and fatal handling ran. Without that final actor callback, intended movement cannot safely become attained evidence. A previous observation also must not survive an advance that refuses before the physical tick.

## Required behaviour

Clear both the previous observation and sample before actor preflight. After actual tick, native entry and fatal handling, consume the sample exactly once before people capture and script drains. Authenticate the admitted physical clock step, original player binding, current frame/epoch and entry/contact/docked/paused/fatal state. Requested time is clamped by the native driver to at most 0.1 seconds. Genuine simulation continues in status and chart views, so camera presentation must not become an extra motion gate.

Observe actual world-unit movement only. A failed observer must discard evidence while retaining committed movement, damage and native entry effects. No route interval, metre conversion, readiness capability, save format or production activation is introduced.

## Validation boundary

Define dedicated tests that call actual `GameRuntime.advance`, covering real movement, clamped time, reads/repeated callback/no tick, simulation views, paused/docked/default-false/fatal states, actual station contact and refused doorway entry, and preflight early refusal. Supplemental callback-input tampering after a genuine actor step tests teleport, stale epoch/player/start and contact-marker refusal without claiming those injected values are native authority. G1 owns compilation/native execution; source checks alone cannot establish acceptance. See [implementation handoff](PR-native-crimbo-actor-motion.md).
