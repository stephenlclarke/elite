# Utility receiving fixture must construct resources from prepared source

Refs [issue46](https://github.com/stephenlclarke/elite/issues/46), PR25 and C08.P05.B.work. The existing hosted190-method run reaches an invalidCommander throw before the owning graph assertions because the fixture marks an actor unloaded before calling the deliberately prepared-only native resource constructor. Preserve that production guard. Build the original native resources while the actor is prepared, then form the intended retained/unloaded fixture.
