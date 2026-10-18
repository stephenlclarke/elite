# test: distinguish solar save boundaries and observe a stopped courier clock

## Observed failures

Review run 352 passes a current solar Commander to the legacy-only loader. Its refusal leaves flight active, so the next launch cannot satisfy the expected docked relaunch calendar adjustment. A separate late crew-refusal argument advances the genuine physical clock past thirty seconds, then asks a disabled-only aiming helper to find the EMP marker that native recovery correctly cleared.

Two pinned courier boundary arguments exhaust the original 20,000-step wait while their clock remains below the deadline. The recorded data delivery clock is 258,971.7000000148 rather than 259,200. The source timing budget is sufficient, and inclusive confirmation with strict after-deadline expiry remains correct. The record lacks the actual first stopped-flight state, so a particular fatal hit, pause or other transition is unproven.

## Required behavior

Prove legacy solar docking with a genuine pre-launch Commander, then separately save an actually docked current world and preserve all current relaunch identity and calendar checks. Aim at the real disabled crew source before waiting for recovery; afterward require a real nearest ray hit on the same recovered logical hull, positive original crew, tools and free hold before testing expired capture authority. Observe the first courier inactive or non-advancing frame without changing routes, clocks, cleanup cadence, limits, control commands or outcomes.

## Scope and risks

Three existing methods cover thirteen cases: one solar, six crew reasons and six courier boundaries. Shared helpers, production and resources stay unchanged. The post-recovery ray remains a required runtime gate; failure must be reported rather than repaired by moving the observer, restoring an EMP marker or resetting time. The courier change is diagnostic only and claims no cause or successful correction. See the [pull request record](PR-solar-crew-calendar-boundaries.md).
