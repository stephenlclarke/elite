# fix(emp): build the victim context before disablement

After the actual electrical drain and combat incident, the existing real-zero branch now constructs its physical context before invoking the private disable helper. The helper receives that unchanged context instead of constructing it inside its large frame. No game mutation occurs between the moved read and its previous position. Actual-zero and deadline checks, original crew and protected-actor checks, complete NPC capture, source custody, random ejection schedule, record validation, per-victim Commander validation and whole-pulse rollback remain unchanged. See [the measured failure](ISSUE-emp-disable-context-lifetime.md).

Strict source formatting and whitespace checks pass. The unchanged seventy-method composed batch, actual emitted stack benefit and final `make ci` remain pending; this source-only change does not establish acceptance. No test, stack setting, concurrency policy or save format changes.
