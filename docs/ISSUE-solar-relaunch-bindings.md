# Solar save parity must account for actual visit rebinding

Full 195 failed the existing dock/load/relaunch Commander comparison because native station actor bindings and main-station observations correctly change on a new visit. Removing the native world from the comparison would hide conservation regressions.

Keep the original celestial, temperature, equipment and Commander checks. Derive the expected station world from the saved world, require each current living station's actual physical body and new visit actor, and update only those bindings and the current original-station observation. Compare the entire resulting world, including poses, conditions, identities, revisions, tombstones and receipt history. See [the repair handoff](PR-solar-relaunch-bindings.md).
