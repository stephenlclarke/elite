# Issue81: keep passive C01 inertia inside the swept interval

Refs [issue81](https://github.com/stephenlclarke/elite/issues/81). Both original actors are profiled NPCs with disabled propulsion. Their drift was applied after native contact completion, so the sweep observed stationary endpoints and the later NPC pass could translate through a hull or add another full step after a collision response.

Move the authenticated passive translation into both existing manual and work-frame pre-completion intervals, exactly once. The later NPC pass must skip C01 propulsion and translation; its zero commanded velocity must not overwrite physical contact momentum. The generic NPC-target inertia refusal may admit only these exact authenticated C01 bodies through their native mass/collision contract. All unrelated profiled actors retain their existing motion owner and guard.

Focused component coverage needs one-step manual/work displacement and conserved native velocity, plus a fast original-recorder crossing whose endpoints lie on opposite sides of the Harrier. The step must collide, destroy or refuse safely rather than tunnel outside the sweep. No journey or broad native campaign is needed.
