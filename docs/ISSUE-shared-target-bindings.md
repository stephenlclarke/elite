# Shared flight target bindings

## Problem and behavior

M02.P01 requires W, Return, E, Q, Tab and F to share one current action authority. The first four used generated definitions, while target selection/filter still had independent Game key literals, help text and a macOS menu label. The Flight menu also lacked the existing target-filter action.

The maintained JSON authority and generator now include Next target (Tab) and Target filter (F). FlightControlInput resolves all six tokens, exposes their scoped help rows and owns the existing held-tool interruption policy. The shared flight dispatcher calls the same cycleAutoTarget/cycleWorkTargetFilter operations previously called by the two direct Game key cases. Those duplicate cases are removed. GameView's Flight menu takes target labels/tokens from the authority and adds the current filter action. Other screen/mission key dispatch remains contextual.

All six generated help rows fit forty columns; the page content capacity accounts for the larger common footer. The generated guide contains the same six bindings on every topic. Historical source provenance is retained; the current authority fingerprint is regenerated from maintained JSON.

## Verification and limits

Eleven offline generator checks and six CI-report fixtures pass, including conflicting target-key rejection and target labels in all fifteen guide topics. Three new isolated Swift methods cover six token/action roundtrips, foreign/function-key rejection, target/tool interruption versus held Fire, and bounded generated/scoped help rows. They are in the fixed GitHub unit selection. GitHub compilation/execution and MBA review proceed asynchronously; no unrun Swift, native menu, whole-help/Game or integration result is claimed.

No key is remapped and no target, hold, weapon or confirmation authority is fabricated. A pending review does not block further development. The separately assigned M02.P02.I24 AppKit latch-reset finding is the next corrective packet; it is not addressed or closed by this control-authority change.
