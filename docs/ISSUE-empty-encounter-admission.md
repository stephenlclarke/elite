# Avoid full station admission checks for empty encounter plans

The original native patrol/docking regression passed validation 306 in 490.748 seconds under Thread Sanitizer, within its unchanged 600-second run budget. A one-second read-only sample of that actual process observed repeated full 372-station source/pose validation through empty salvage/cargo encounter admissions inside the unchanged docking flight loop. The normal physical frame already adopts actors before advancing encounters.

An encounter plan with no spawn requests always produces no admission receipts. Avoid using it to adopt unrelated bodies or repeat station admission preflight. Every actual spawn request must retain its original initialization, context, geometry, population, identity and source checks. Keep the full flight fixture, physical timing, docking proofs and sanitizer concurrency intact.
