# Retain the original courier physical-arrival failure

Validation 355 reached the corrected Tab station selection but the first original courier route ended after 618 approach frames with `APPROACHING` and `GAME OVER`. The original physical arrival assertion failed. Only pre-approach screenshots and that terminal message were recorded; neither fatal cause nor final crew/law/motion can be reconstructed from them.

The generic game-over message follows energy depletion and can overwrite prior docking collision messages. Real station impact and real weapon damage must remain separate possibilities until actual final state is captured. Preserve the unchanged physical path, traffic, celestial bodies, controls, time steps, original approach budget and all delivery/custody oracles.
