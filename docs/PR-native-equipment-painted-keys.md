# Match native equipment fixtures to painted keyboard input

## Change

The normal equipment fixture key helper now draws through its existing capture path before protected keyboard input. It decodes the actual queued page-key packet and checks both the key and the actual painted presentation. Equipment Return retains its dedicated purchase-intent assertion and real delegate consumer. Raw unprotected shortcuts retain their existing checks.

The inventory fast-focus test now checks that its sole queued action is a Tab packet with the captured painted presentation, while still requiring no purchase/fitting intent. Its deliberately unpainted and stale input helpers remain unchanged. The negative inventory case compares any retained prior paint with the current undrawn interaction, requires an available current action, and still verifies Return refusal and full Commander conservation. It does not assume the retained presentation storage is empty.

## Validation and limits

Strict Swift formatting, whitespace checks and Markdown lint passed. All stale/duplicate purchase, pointer/window geometry, fitting, pricing, Commander and save-byte assertions remain intact. No production code, selection mutation or manufactured packet was introduced. Compilation and native regression execution remain pending the coordinating validation lease.

See [the issue](ISSUE-native-equipment-painted-keys.md).
