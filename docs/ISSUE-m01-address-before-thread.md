# Require the complete address chain before thread preparation

The recoverable quality workflow currently lets address and thread preparation become eligible together after authorization. Their shared runner labels do not establish an order. This does not enforce the assigned ASAN-first execution sequence.

Make thread preparation depend on authorization, address preparation and address shards. Require successful address preparation and either successful address shards or a skipped shard job with an explicit `has_pending == 'false'` output. Failures, cancellations and missing pending state must block thread preparation and must never pass the required physical aggregate.

Keep all existing gates, source and policy pins, authorization, runner labels, selectors and sanitizer requirements. Limit this component to the workflow dependency and condition, one additive workflow fake fixture and this documentation pair. Start from reviewed `28c4a43818c6825cb2ecf5cb878df420923dd7cf`; resource admission helpers and their separate tests belong to MC1. [Implementation and validation](PR-m01-address-before-thread.md).
