# Issue40: recorder loss fails after a legitimate hull exchange

[MBA issue40](https://github.com/stephenlclarke/elite/issues/40) identified a source defect in pickup head25e6f859. The recorder capture permanently names its pickup hull. Actual main-station hull exchange transfers mission property to a fresh owned hull UUID, but the later loss validator compares that current loss hull to the immutable pickup hull. Escape consequently aborts and destruction cannot publish the loss/release its tonne.

Preserve the original pickup while tracking current custody through the actual portable-equipment exchange. Later loss must use that attained holder; unrelated hulls/owners must still fail. Keep historical custody valid after loss and subsequent unrelated exchanges. Add focused portable-transfer/escape/destruction and strict-save regressions. See [PR notes](PR-40.md) and [PR25](https://github.com/stephenlclarke/elite/pull/25).
