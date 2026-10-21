# test: construct authentic historical saves and verify EMP refit publication

## Observed problems

Three existing tests fail in preserved review run 352 because their save assumptions predate current native state. The cabin test first loads a genuine raw legacy Commander successfully, then copies a current generation and labels it schema 4. The courier test similarly labels a current writer's generation schema 20 and later encodes its already-mutated Commander as raw. Current drive and economy fields correctly refuse both historical claims. Neither failure demonstrates lost cabins or rejected authored keyword data.

The free-refit command grants actual owned EMP hardware. That changes the game's durability predicate from false to true and automatically publishes a versioned save to its bound destination. An after-command no-file assertion is therefore obsolete, and decoding the published pointer directly as a Commander fails. Existing item preservation, virtual freight, cash and XYZzy rules, contract refusal and inventory storage remain required.

## Required behavior

Build complete historical chunks from untouched pre-runtime values, preserving original ownership and world state. Schema 4 uses three untyped chunks and no value codec; schema 20 uses four tagged chunks and its authentic codec. Raw courier input must use the same original Commander. Keep all pointer, chunk and raw input bytes unchanged during nonpersisting loads. Verify the genuine EMP durability transition and strict current publication instead of suppressing it, then preserve explicit save as a separate generation and retain actual contract and inventory checks.

## Scope and risks

Only three existing methods and three cases change, with no shared helper, production, schema, historical example, negative companion or asset changes. The old cabin marker is intentionally invalid until its supported migration removes it; no pre-migration validity requirement is introduced. Runtime validation is pending review. See the [pull request record](PR-authentic-historical-and-refit-fixtures.md).
