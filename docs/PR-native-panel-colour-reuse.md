# Reuse each native panel colour

Create the panel colour once and pass it to both existing fill and stroke setters. Keep the colour helper, alpha interpretation, path construction, overlap stroke, antialiasing, material values and painter order unchanged. No shared state or cache is introduced.

One focused offscreen test compares all bitmap bytes against the original two-colour drawing sequence for overlapping materials, empty and degenerate panels in a single scaled frame. Focused execution and independent review are pending. No standalone native measurement is planned for this small change; any timing comparison will be batched with a meaningful rendering delivery. No smoothness or full CI acceptance is claimed.

Owner qualification completed on unchanged73174c2d8699095e6a9d780c9da5fc5eca3895c7: matching790 DEBUG coverage compilation and791 one native full-bitmap parity case PASS, zero issues. Independent Root bugs/performance/style review is CLEAN; actual terminals/all owned processes closed and protected source/preferences/artifacts stayed unchanged. G1 imported the four hash-exact files as81b3b0b064d3ad7b2e3f8390a687ff94b892e84c. Full evidence is in the central completion ledger. This remains a supporting optimization with actual timing gain unmeasured; no standalone native comparison or smoothness/release acceptance.
