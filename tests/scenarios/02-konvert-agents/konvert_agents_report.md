# Test Report: test_konvert_agents

| Field | Value |
|-------|-------|
| Status | **FAIL** |
| Date | 2026-04-17T20:31:13Z |
| Duration | 562.4s |
| Session ID | `6f9399a2-4c19-480a-9ec6-e782ff37c2bf` |
| Cost | $0.2095614 |

## Environment

| Setting | Value |
|---------|-------|
| Model | unknown |
| Exit code | 0 |
| init.sh invoked | no |
| Context window | unknown |

## Agent Activity

_No OMC mission state found._

## Artifacts Produced

| Expected | Found at | Status |
|----------|----------|--------|
| PLAN.md | -- | MISSING |
| STATE.md | -- | MISSING |
| REVIEWS.md | -- | MISSING |
| INSIGHTS.md | `IMPROVEMENTS.md` | WRONG LOCATION |


## Scenario Steps

| # | Step | Duration | Status | Detail |
|---|------|----------|--------|--------|
| 1 | start | 87.4s | PASS | Launch orchestrator with konvert project context |
| 2 | init-q1-answer | 300.1s | FAIL | Agent asks about phases/milestones or proceeds |
| 3 | init-q2-answer | 129.8s | PASS | Answer INIT question 2 |
| 4 | init-q3-answer | 20.1s | PASS | Answer INIT question 3 and confirm plan |
| 5 | delegation | 25.1s | PASS | Let agent work through delegation (long-running) |

## Acceptance Criteria

| AC | Result | Detail |
|----|--------|--------|
| STEP-1 | PASS | Step [start]: Launch orchestrator with konvert project context |
| STEP-2 | FAIL | Step [init-q1-answer]: Answer INIT question 1 -- output_matches: output does not match pattern: '(?i)(phase\|milestone\|question\|jalons\|etape\|plan\|proceed\|contrainte\|c |
| STEP-3 | PASS | Step [init-q2-answer]: Answer INIT question 2 |
| STEP-4 | PASS | Step [init-q3-answer]: Answer INIT question 3 and confirm plan |
| STEP-5 | PASS | Step [delegation]: Let agent work through delegation (long-running) |
| FA-1 | PASS | Last step exited cleanly |
| FA-2 | PASS | konvert.sh exists |
| FA-3 | PASS | konvert.sh is executable |
| FA-4 | PASS | test_konvert.sh exists |
| FA-5 | PASS | test_konvert.sh is executable |
| FA-6 | PASS | PLAN.md created in session directory |
| FA-7 | PASS | PLAN.md contains phase information |
| FA-8 | PASS | STATE.md created in session directory |
| FA-9 | PASS | REVIEWS.md exists |
| FA-10 | PASS | CHECKPOINT.yaml exists |

## Consumption

| Metric | Value |
|--------|-------|
| Duration (API) | 17.2s (0.3min) |
| Duration (API calls only) | 17.0s |
| Turns | 2 |
| Total cost | $0.2096 |
| Stop reason | end_turn |
| Input tokens | 4 |
| Cache (create/read) | 49,672 / 48,098 |
| Output tokens | 590 |

## Diagnosis

_No diagnosis provided._

## Workspace

- **Path**: `/tmp/kiss-claw-konvert-t0llzo0w`
- **Preserved**: yes
