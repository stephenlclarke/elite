# Control guide consistency

Delivered together in [PR #11](https://github.com/stephenlclarke/elite/pull/11). See [the integrated validation and release evidence](PR-11.md) and [request checklist](DELIVERY-BACKLOG.md).

## Motivation

The control guide still described a showroom without purchases, used retired source/refit button labels, and omitted the distinction between reload and Open. Title help always claimed a new Jameson even after restoration.

## Implementation

Align documentation and contextual help with existing exchange confirmation, current source/game buttons, galactic-chart brackets, profit-scan P, save shortcuts and startup continuation. No control behavior changes. The separate owned-ship wording correction remains with integration.

## Validation

Compared the guide with AppKit menu mappings, Game/ScreenNavigation handlers, showroom/trade handlers, chart navigation and startup restoration. Markdown lint and diff whitespace checks pass. No simulation or input behavior changed; final combined CI remains with the main implementation session.

## Compatibility and risks

Built-in MacBook keys remain sufficient. No save schema, geometry, media or rendering changes.
