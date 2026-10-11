# Contributing to Hangisi Daha

## Repository Preflight

Before starting implementation:
- Verify the correct repository root and current working branch.
- Inspect working-tree state to ensure it is clean and matches expectations.
- Verify remote tracking branch parity when relevant.
- Detect unexpected uncommitted changes. Never perform destructive recovery (such as `git reset --hard`, `git stash`, or `git clean`) to resolve unknown state; stop and report unexpected changes.

## Scope and Product Boundaries

- Implement only within the accepted task scope.
- Do not invent product behavior or silently expand architecture.
- Distinguish local technical decisions from product decisions. Local implementation details may be decided freely as long as they do not alter product behavior or architectural direction.
- Repository implementation facts must not automatically be treated as product decisions.

## Validation and Test Integrity

- Run relevant validation, analysis, tests, or builds appropriate for the task.
- Do not hide coverage loss or regressions by deleting, disabling, or skipping tests merely to make checks pass.
- If existing behavior and expected behavior disagree, investigate the cause rather than masking evidence.

## Offline Migration Safety

- Hangisi Daha is in an offline migration.
- Do not collapse subsystem state into broad claims: gameplay being offline does not imply that every subsystem or the entire application is offline.
- Subsystem state must be verified independently; do not generalize beyond verified subsystem behavior.

## Implementation State Terminology

Keep implementation lifecycle states distinct:

`discussed → planned → started → implemented → verified`

A plan is not an implementation, and code completion does not equal verification.
