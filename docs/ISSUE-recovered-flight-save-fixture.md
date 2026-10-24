# Recovered flight mutation needs its genuine durable writer

Full run 222 reports `.refused(.invalidState)` where the recovered-source actor fixture expects its flight transaction to apply. Actual launch creates native station and calendar state requiring durability, but the flight runtime has no save destination. The actor explicitly refuses and rolls back mutations in that situation. The existing negative no-destination tests correctly cover that refusal.

Bind this positive flight fixture to an isolated real save destination and verify its versioned publication while preserving the original captured command across the advance. Do not suppress native state or weaken the publication barrier. See [the correction](PR-recovered-flight-save-fixture.md).
