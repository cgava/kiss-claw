# Test Report: test_konvert_agents

| Field | Value |
|-------|-------|
| Status | **FAIL** |
| Date | 2026-04-15T06:43:20Z |
| Duration | 82.6s |
| Session ID | `5dd59c20-3022-4548-b226-c51434f7bc81` |
| Cost | $0.28370805 |

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
| INSIGHTS.md | -- | MISSING |

## Acceptance Criteria

| AC | Result | Detail |
|----|--------|--------|
| AC-1 | PASS | Exit code is 0 |
| AC-2 | PASS | JSON response is parseable |
| AC-3 | FAIL | PLAN.md exists -- not found anywhere |
| AC-4 | FAIL | STATE.md exists -- not found anywhere |
| AC-5 | FAIL | konvert.sh exists -- not found |
| AC-6 | FAIL | test_konvert.sh exists -- not found |
| AC-7 | FAIL | REVIEWS.md exists -- not found anywhere |
| AC-8 | PASS | Insights file not found (soft — not required) |
| AC-9 | PASS | CHECKPOINT.yaml not found (soft — not required) |

## Consumption

| Metric | Value |
|--------|-------|
| Duration (API) | 78.6s (1.3min) |
| Duration (API calls only) | 59.3s |
| Turns | 15 |
| Total cost | $0.2837 |
| Stop reason | end_turn |
| Input tokens | 16 |
| Cache (create/read) | 33,717 / 365,621 |
| Output tokens | 3,169 |

## Diagnosis

_No diagnosis provided._

## Workspace

- **Path**: `/tmp/kiss-claw-konvert-1y5f2oyf`
- **Preserved**: yes
