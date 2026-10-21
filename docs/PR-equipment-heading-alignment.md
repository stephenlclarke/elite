# fix(ui): align equipment headings and simplify fuel label

The equipment column heading now shares the category headings’ left position. The fuel category reads `Fuel Storage` with exactly one space. Item indentation, the selection marker, and the right-aligned price/status column retain their existing positions. See [the problem](ISSUE-equipment-heading-alignment.md).

Source inspection confirms the heading coordinates match and the label contains one space. No tests were added for these reversible label and position edits. Formatting and whitespace checks cover this isolated source change; rendered verification and integration remain with the canonical validation owner after the active full run closes. No native, build, media, or CI jobs were run for this change.
