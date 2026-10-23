# M02.P05.status-dock-context: truthful Status location

## Problem

Status always falls back to "Station: Main orbital station" when no RRS station name is present. That also happens while flying, and can make an unknown dock look like a known main station.

## Scope and acceptance

Project the existing docked flag, main-station flag and native station name into the Status row. An undocked ship must not claim a station from retained dock metadata. Known main/waystation/headquarters names remain intact. A docked ship without a known location reports the uncertainty. Do not change docking, service authority, navigation, Inventory or mission state.

Parent: [M02.P05 / F07,F43](COMPLETION-LEDGER.md). This is a component presentation feature; gameplay and release acceptance remain separate.
