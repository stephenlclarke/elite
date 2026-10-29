# Evaluate Crimbo test operations before assertion macros

## Problem

Focused validation run 315 compiled production core but stopped during test compilation. A throwing provider-facts query inside `#require` lost its throwing context in the expanded call, and two mutating electrical drains inside `#expect` expanded against immutable arguments. Tests did not execute.

## Required correction

Evaluate the throwing query and each drain once into a local result before the existing assertion. Preserve the same arguments, order, optional requirement, Boolean assertions and expected-throw closures. Audit the three Crimbo test sources for remaining direct throwing or mutating macro operands.

## Validation boundary

Only the two affected test files and this issue/PR pair change. Source formatter/parser, scoped lint, Markdown and diff checks are permitted here. G1 owns eventual compilation and native test execution. See [implementation handoff](PR-native-crimbo-test-macros.md).
