# Reuse each native panel colour

Create the panel colour once and pass it to both existing fill and stroke setters. Keep the colour helper, alpha interpretation, path construction, overlap stroke, antialiasing, material values and painter order unchanged. No shared state or cache is introduced.

One focused offscreen test compares all bitmap bytes against the original two-colour drawing sequence for overlapping materials, empty and degenerate panels in a single scaled frame. Focused execution and independent review are pending. No standalone native measurement is planned for this small change; any timing comparison will be batched with a meaningful rendering delivery. No smoothness or full CI acceptance is claimed.
