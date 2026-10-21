# Raw commander loads do not suspend missing missions

The raw JSON load path migrates retained mission equipment and calendar state but omits the unavailable-content check used by versioned saves. An active mission whose exact pack is absent can therefore remain unsuspended after loading.

Apply the existing missing-pack policy before publishing the loaded commander. Preserve every retained item, loan, condition, receipt and source-file byte when migration persistence is disabled. See [implementation](PR-raw-save-missing-missions.md).
