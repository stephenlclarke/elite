# Update obsolete locked-stage boundary expectations

Hosted correction442ba0f3/run39693528460 compiled the affected ark state and executed121 methods, including all six receiving methods successfully. Its two failures are older continuation/service assertions expecting `laterStages` to contain `7-14`. Receiving now implements stage7, so the source correctly locks `8-14`. See [issue39](https://github.com/stephenlclarke/elite/issues/39). The original receiving compile failure and this failed batch remain distinct; full qualification is still pending.
