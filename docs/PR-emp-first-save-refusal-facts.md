# Record bounded facts after the actual EMP first-save failure

The existing regression catches its first save failure, snapshots the unchanged runtime, and records bounded native preparation and scene refusal facts before rethrowing the original error. Native preparation is repeated only on an isolated value after failure, using the existing first-refusal diagnostic. This observation writes no file, publishes no runtime state, changes no timer or archive, and is never admission authority.

Validation: source review only; the actual CI 667 failure is retained. Execute this same regression with the reviewed completion-stack repair and other affected cases. A successful save avoids the diagnostic entirely. If all observed preparation and scene checks pass, the message explicitly leaves the original writer failure unexplained rather than inventing a stage. Runtime and product behavior are unchanged.
