# Show economy through planet terrain and weather

FR031 requests visibly different planet appearance by economy. The previous preview discarded the inspected system's economy and selected one of four identity-based palettes. Both renderers used fixed highland, cloud and atmosphere parameters, so industrial and agricultural worlds could look alike.

Carry the actual economy into an immutable shared appearance profile. Define explicit art direction for all eight economy classes: industrial worlds have subdued terrain, sparse vegetation, more cloud and murky haze; agricultural worlds have greener terrain and clearer weather. Retain deterministic identity variation, stable terrain generation and existing bounded caches. Government must remain an independent gameplay input.

CPU fallback and GPU shading must apply the same profile and formulas. Include appearance in rendered-image cache identity, while retaining identity-only terrain caches. Preserve asynchronous GPU readiness, lighting, framing, transparent space and existing wireframe paths. Asteroid ring incidence and save migration belong to FR032 and are outside this change.
