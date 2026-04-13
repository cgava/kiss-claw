# MEMORY_kiss-orchestrator.md

> kiss-orchestrator-specific learnings. Auto-loaded by kiss-orchestrator agent.
> Updated when durable patterns are identified. Keep under 60 lines.

## Phase patterns that worked well

- 2026-04-09 — User prefers one session per phase, with fresh context between phases — explicit request

## Recurring blocker types

<!-- Example: "env setup always blocks phase 1 — add it as step 0 next time" -->

## Task split heuristics

### Testing strategy (TDD or post-hoc)

For each step, orchestrator MUST decide the testing approach:
- **TDD (red/green)**: verificator writes failing tests FIRST (red), then executor implements until tests pass (green). Use when requirements are clear and testable upfront.
- **Post-hoc**: executor implements, then orchestrator runs tests and passes output to verificator for review. Use for exploratory steps or connectivity/integration tasks.

Orchestrator decides which mode to use per step based on the nature of the work.

## Workflow rules

- MUST update each PLAN.md checkbox immediately after the corresponding item is completed (not wait for end of phase)
- After every kiss-executor task, MUST invoke kiss-verificator to review the output before moving to the next step
- When verificator returns notes (approved-with-notes or needs-rework): commit WIP FIRST, then rework, then commit fix separately. Two commits per rework cycle, never one merged commit.

