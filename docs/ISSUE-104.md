# Fresh commission validation enters the present-recorder stack frame

[Issue 104](https://github.com/stephenlclarke/elite/issues/104) records the attributed failure in [PR 100](https://github.com/stephenlclarke/elite/pull/100) at `3938ad9d13593002f64325bf9aef0f6e393cf41f`. Hosted run `39786836850` compiled in 881.84 seconds, then exited with signal 10 before any completed test methods. Its retained stack points to the stack probe in `NativeC01SurveyorSave.valid`, reached during fresh commission acceptance when no surveyor exists. This is distinct from the station-entry failure in issue 88.

The absent-surveyor path must retain its original missing-owned-group refusal without entering the large present-recorder validator frame. All present-recorder shape and custody checks must remain intact. See [the correction](PR-104.md).

## Present-recorder boundary on composed source

The single focused execution at52acd4bb compiled in231.62seconds, then exited
signal10 with zero completed methods and unfinished52-byte XML. A separately
authorized one-time debugger replay of the existing binary and same four-method
selection captured PID10856/thread19 fault0x16fe03fb0 and SP0x16fe03f90 inside
actual guard0x16fe00000-0x16fe04000. Image UUID3995B2CC-E639-372D-931A-75F89E5D2370
and its retained hash bind that capture to the composed source.

The faulting caller chain enters NativeC01Surveyor.shapeValid from the present
surveyor validator, full Commander/save-publication checks and the original
Sorel confirmation method. This is a present-recorder boundary, separate from
the earlier absent-surveyor split and station-world issue137. Debugger results
are diagnostic evidence, not test qualification. Existing evidence remains in
`/tmp/elite-100-composition-diagnostic`; no original failure is relabelled.

The first ownership-only follow-up at1edfe2d9 compiled in80.10seconds but its
single normal affected run still exited signal10 after94.408seconds, with no
completed methods and unfinished XML. That result has no new fault stack and
is not assumed to reproduce an identical frame. The existing captured shape
boundary remains the source-supported repair target; no second diagnostic
replay was performed.

The first helper-split head2eb32553 failed compilation in17.028seconds: the
right-hand autoclosure of `&&` consumed the borrowed state. No tests ran at that
head. Replace that expression with an explicit capture guard and loss return,
preserving left-to-right short-circuit behaviour without an autoclosure.

## Reservation-audit reader attribution

The explicit-guard split atd03006c6 compiled in76.94seconds but the normal
check exited signal10 after91.215seconds, with zero completed methods. Its
changed-source debugger capture retained UUIDA046A9E9-14F2-3F5E-B66D-A11E788BDD15,
PID34127/thread21, fault0x16ff1bfb0 and SP0x16ff1bf60 in the actual guard
0x16ff18000-0x16ff1c000. The caller chain reaches ReservationAuditSave.shapeValid
through allSatisfy, sourceValid, valid and full event publication during the
existing stale-input fixture's fresh acceptance. This is a newly attributed
audit-reader path, not an assumed recurrence in the surveyor helper. Capture
records remain in `/tmp/elite-104-d030-diagnostic`; debugger exit0 is not a pass.
