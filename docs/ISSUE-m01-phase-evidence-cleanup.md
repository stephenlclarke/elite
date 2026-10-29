# Frozen phase evidence blocks the next guarded checkout

## Problem

After the successful M01 PR run, main CI40851436561 failed before testing or Sonar. The guard called `git clean -ffdx -e /.build/`; the workspace still contained the original successful phase cache under `reports/quality-phases/`. Its proof files are mode0400 and attempt directories0500. Git cannot unlink those children. A private copy preserving the actual modes and paths reproduces exit1 and `Permission denied`. The original guard error exposed only its safe SubprocessError category.

## Required correction

Preserve that exact root phase-evidence path as well as the build cache. Continue removing other ignored/untracked inputs, especially unexpected source files. Preserve proof bytes and permissions; do not chmod originals, relocate caches, broaden source trust, reuse failed results or introduce a new cleanup framework.

## Validation and boundary

Use the existing local-runner unit workflow with a real temporary Git checkout, frozen proof, build cache and stale source/report inputs. Prove the original command fails the same regression and the corrected command passes. Actual main quality/Sonar and signed/notarized publication remain pending. See [implementation](PR-m01-phase-evidence-cleanup.md).
