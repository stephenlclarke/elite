# Audit actual app-save readers and preserve historical format coverage

The actual-save diagnostic 317 proves that current native app publication writes schema 26 and required policy/calendar metadata. Several integration tests still decode that output as raw Commander data. A reference-NPC fixture also creates bodies 40/41 without advancing the body allocator. These are actual app-save callers; pure JSON roundtrips and forged raw authority tests have different contracts and must remain unchanged.

Two durability tests likewise confuse the current app writer with historical format construction. Preserve the inventory/library predicate before a save, then test the real current publication contract. Construct genuine format-21 and format-25 fixtures through the supported historical store with compatible headers; do not patch version numbers or admit current drive-equipped raw data.

The old ordinary hull trade test combines two states. After a current versioned save establishes retained policy/calendar state, a blocked publisher must refuse the trade atomically. A genuinely nondurable local actor can complete a local trade before its first current save; a later explicit save failure must preserve that accepted local property. Test both states and their actual bytes, funds, gear and retry behaviour.

[PR-native-save-caller-audit.md](PR-native-save-caller-audit.md).
