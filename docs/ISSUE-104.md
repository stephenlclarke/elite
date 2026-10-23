# Fresh commission validation enters the present-recorder stack frame

[Issue 104](https://github.com/stephenlclarke/elite/issues/104) records the attributed failure in [PR 100](https://github.com/stephenlclarke/elite/pull/100) at `3938ad9d13593002f64325bf9aef0f6e393cf41f`. Hosted run `39786836850` compiled in 881.84 seconds, then exited with signal 10 before any completed test methods. Its retained stack points to the stack probe in `NativeC01SurveyorSave.valid`, reached during fresh commission acceptance when no surveyor exists. This is distinct from the station-entry failure in issue 88.

The absent-surveyor path must retain its original missing-owned-group refusal without entering the large present-recorder validator frame. All present-recorder shape and custody checks must remain intact. See [the correction](PR-104.md).
