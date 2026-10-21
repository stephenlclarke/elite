# Mission UI composition

## Motivation

The accepted mission engine contains campaign gallery, contract board and reference library models, but the current presentation and native menu must compose these with the latest navigation, inventory and flight controls.

## Expected behavior

Expose mission destinations and trial actions through the Game menu. Render contracts and the mission library using their existing responsive renderers. Keep the existing numbered screens and flight shortcuts. Preserve stable gallery selection when installed legacy packs change, including scripted entries whose row moves.

## Scope and compatibility

This slice owns presentation, navigation, help, gallery composition and a new main-actor menu helper. Game state and native event-loop integration remain with G1. There are no save schema, equipment, renderer asset or simulation changes in this slice.

## Acceptance

Independent source review, focused composition/menu tests after the G1 hooks land, native docked and flight interaction checks, and the shared `make ci` gates are required. Heavy validation is deferred while G1 holds lease 031. No build or runtime result is claimed here.
