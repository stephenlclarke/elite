# Isolated GitHub unit execution

## Problem and behavior

The development workflow requires GitHub to execute isolated units while MBA reviews code/results. The existing quality workflow runs mixed full-game and sanitizer work, so it cannot serve as the development unit selection without initiating prohibited integration execution.

The new Isolated Unit Tests workflow runs `make unit-ci` on development source pushes, main and pull requests. A fixed maintained list now selects fifteen methods (including two trackpad contact-safety methods) from geometry/impulse, native utility codecs, measured-extraction domain/codec and bundled-pack parsing. No issue/comment input is executed, and no whole mixed suite is selected. A toolchain-keyed incremental build cache reduces repeat compilation. A running branch job is allowed to finish while the newest pending head waits, so repeated feature pushes do not continually cancel the first cold build. Read-only workflow permissions and pinned Actions match repository conventions.

The runner retains exact commit, fixed command, combined output and xUnit report; it requires every selected method and rejects empty, incomplete, unselected, skipped or failed reports. Swift Testing's suffixed xUnit filename is handled explicitly. Six Python unit fixtures cover report completeness and failure cases. The README adds the workflow badge and documents the same local target.

## Verification and compatibility

Six report/selection fixtures passed. The final local runner completed all thirteen selected Swift methods and accepted its actual nonempty Swift Testing XML report. The first runner attempt correctly failed because SwiftPM wrote a suffixed filename; all thirteen selected methods had passed, and the parser was corrected before publication. No integration, GUI, mission journey, broad CI, sanitizer, leak or Sonar execution occurred.

The existing `quality` required check remains configured with strict branch protection and GitHub App 15368. Neither that workflow nor branch protection is changed. Existing Sonar install/analysis guards still require actual main and exclude pull requests; the scan script still requires a clean committed main and exact SHA/Previous version. No branch or PR Sonar scan is added. The current no-integration development phase therefore cannot claim the legacy broad `quality` merge obligation satisfied; a later authorized merge/release phase must resolve it. Unit results are not coverage-gate, review approval, app or release acceptance.
