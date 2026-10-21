# Provider reference normalization violates Swift exclusive access

## Problem

Focused validation run 314 stopped before test execution at canonical `c4478d96aa5c5088e7a15d4a7ddc8feaa6e036ed`. The compiler reported overlapping access to `self.entries` at `NPCPersistenceLedger.swift:426`. In `normalizeProviderReferences(protection:)`, assigning through the dictionary's optional nested snapshot opens mutable access while `bindingReferences` reads that same dictionary to resolve logical references.

## Required correction

Read the complete entry into a local value, compute its normalized snapshot, then write the entry back after the helper returns. Preserve the existing loop, reference resolution, bindings, offers, terminal state and transactional validation. No resource or clock policy changes are needed.

## Validation boundary

This source worker may perform formatter/parser, scoped strict lint, Markdown and diff checks only. G1 owns failed-run closure and eventual compiler/native test validation. See [implementation handoff](PR-npc-provider-ledger-exclusivity.md). No test execution or native acceptance is claimed from this correction.
