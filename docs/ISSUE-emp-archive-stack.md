# EMP archive capture exhausts a cooperative thread stack

Full CI 447 at `d0dd9ce3fad1c300ed719521aa24bbbc447cb1c6` crashed with SIGBUS and “Thread stack size exceeded” on a 544 KiB cooperative thread. The matched stack enters `captureEMPArchiveState` through EMP persistence, salvage persistence, native save preparation and a durable timer callback. Each function appears once; this is not evidence of recursion. Individual frame contributions have not been measured.

The absent archive check currently lives inside capture alongside archive, record and physical-body temporaries. Present archives need bounded record lifetimes as well. Preserve the stray-EMP actor rejection, initial/final archive validity guards, custody and scene checks, and capture assignment before scene validation. Preserve save representation and failed-writer behavior.

The repair is restricted to `EMPPersistenceRuntime.swift`, a new regression file and these notes. G1 owns compilation, focused execution, compiled frame evidence and maintained CI. No stack-size or serialization workaround is permitted.

[Proposed repair](PR-emp-archive-stack.md).
