# Native actor resolution retains unnecessary simulation copies

A controlled debugger probe of the exact compiled coverage candidate stopped in `currentMissionActorDescriptor` during real NPC laser damage in the component-contact regression. The existing descriptor and fitting helpers take the entire value-type game through nested calls even though they need only the current bodies, installed mission content, ownership records and geometry.

Keep every live ownership, unique body, installed content, component, geometry and native binding check. Reduce the resolver inputs without changing descriptor authority or damage behaviour. The original component-contact, foreign-owner, source-binding and combat regressions must run normally, followed by complete CI. See [implementation and evidence limits](PR-native-actor-resolution-lifetime.md).
