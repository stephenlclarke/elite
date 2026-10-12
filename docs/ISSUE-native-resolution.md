# Enlarged space graphics and crawling stars

## Problem

The flight screenshot shows large stair steps around the planet and stars shaped like short diagonal worms. Ship strokes were smoothed in a separate image, but planets, stars, cockpit shapes and charts still came from the enlarged 256-square raster. The offscreen image also ignored Retina backing resolution.

Star positions were calculated from integer-rounded elapsed time multiplied by the current speed. Changing throttle moved the entire star pattern instantly, and high speed added a fixed diagonal tail unrelated to the viewing direction.

## Expected behaviour

Geometry draws at the display's native resolution and resizes cleanly. Stars are small round points moving continuously with the ship in all four views. The original bitmap font and keyboard layout remain available as requested.

## Reproduction and acceptance

Native regression tests reproduced both failures: the enlarged planet had zero antialiased shades, and changing speed without advancing time changed the space image. The fix must pass those checks, preserve the original glyph pixels, verify frame-rate-independent star movement and bounded recycling, and pass the coverage, sanitizer, leak and main-branch Sonar gates.

Implementation: [PR-native-resolution.md](PR-native-resolution.md).
