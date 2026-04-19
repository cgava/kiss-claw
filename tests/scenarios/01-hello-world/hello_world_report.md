# Test Report: test_hello_world

| Field | Value |
|-------|-------|
| Status | **PASS** |
| Date | 2026-04-17T20:21:50Z |
| Duration | 18.5s |
| Session ID | `b4775225-fbdb-46fb-ba90-3489e541cfdf` |
| Cost | $0.053472500000000006 |

## Environment

| Setting | Value |
|---------|-------|
| Model | unknown |
| Exit code | 0 |
| init.sh invoked | no |
| Context window | unknown |

## Agent Activity

| Agent | Role | Duration | Status |
|-------|------|----------|--------|
| kiss-verificator:a79855d | kiss-verificator | n/a | done |
| kiss-executor:ad74ade | kiss-executor | n/a | done |
| kiss-executor:a334bad | kiss-executor | n/a | done |
| kiss-verificator:a43f3ee | kiss-verificator | n/a | done |
| kiss-verificator:af60ff1 | kiss-verificator | n/a | done |
| kiss-executor:a3feda8 | kiss-executor | n/a | done |
| kiss-verificator:a79e31a | kiss-verificator | n/a | done |
| kiss-executor:a7403ff | kiss-executor | n/a | done |
| kiss-executor:a57ce43 | kiss-executor | n/a | done |
| kiss-executor:a7cc12f | kiss-executor | n/a | done |
| kiss-executor:a4c9564 | kiss-executor | n/a | done |
| kiss-verificator:a140f0f | kiss-verificator | n/a | done |
| kiss-verificator:a5a8a8d | kiss-verificator | n/a | done |
| kiss-verificator:a8e974d | kiss-verificator | n/a | done |
| kiss-verificator:a0aa200 | kiss-verificator | n/a | done |
| kiss-executor:a38fad3 | kiss-executor | n/a | done |
| kiss-verificator:a35f0b1 | kiss-verificator | n/a | done |
| kiss-executor:a33c241 | kiss-executor | n/a | done |
| kiss-executor:a44e77d | kiss-executor | n/a | done |
| kiss-executor:aa3a17f | kiss-executor | n/a | done |
| kiss-verificator:a45c329 | kiss-verificator | n/a | done |
| kiss-verificator:a639a23 | kiss-verificator | n/a | done |
| kiss-verificator:adb11ab | kiss-verificator | n/a | done |
| kiss-executor:a33af5f | kiss-executor | n/a | done |
| kiss-verificator:a3c7914 | kiss-verificator | n/a | done |
| kiss-executor:a98baa1 | kiss-executor | n/a | done |
| kiss-executor:a1d9bc5 | kiss-executor | n/a | done |
| kiss-verificator:aa04948 | kiss-verificator | n/a | done |
| kiss-verificator:ae2e525 | kiss-verificator | n/a | done |
| kiss-executor:a227801 | kiss-executor | n/a | done |
| kiss-executor:a06d2b6 | kiss-executor | n/a | done |
| kiss-verificator:ae3d9e3 | kiss-verificator | 52s | done |
| kiss-verificator:a117e78 | kiss-verificator | 23s | done |
| general-purpose:a06e39c | general-purpose | n/a | running |
| general-purpose:a33b5ff | general-purpose | n/a | done |
| general-purpose:a5a0afb | general-purpose | n/a | done |
| general-purpose:ae4e25f | general-purpose | n/a | done |
| general-purpose:a52ad24 | general-purpose | n/a | done |
| general-purpose:ad91213 | general-purpose | 171s | done |
| general-purpose:a02fdb1 | general-purpose | 952s | done |
| kiss-orchestrator:a985dc7 | kiss-orchestrator | n/a | done |
| kiss-executor:a6aeea2 | kiss-executor | n/a | done |
| kiss-executor:a5aead4 | kiss-executor | n/a | done |
| kiss-verificator:ab7b414 | kiss-verificator | n/a | done |
| kiss-executor:a2b7c0e | kiss-executor | n/a | done |
| kiss-executor:a124cef | kiss-executor | n/a | done |
| kiss-verificator:ac9008f | kiss-verificator | n/a | done |
| kiss-verificator:a5ba4b0 | kiss-verificator | n/a | done |
| kiss-executor:a4015a2 | kiss-executor | n/a | done |
| kiss-verificator:aa9720f | kiss-verificator | n/a | done |
| kiss-executor:ac55f34 | kiss-executor | n/a | done |
| kiss-verificator:ac42da8 | kiss-verificator | n/a | done |
| kiss-executor:aec7892 | kiss-executor | n/a | done |
| kiss-verificator:a8b8775 | kiss-verificator | n/a | done |
| kiss-executor:a603416 | kiss-executor | n/a | done |
| kiss-verificator:a18fc3a | kiss-verificator | n/a | done |
| kiss-executor:abbc5ce | kiss-executor | n/a | done |
| kiss-verificator:ad27db8 | kiss-verificator | n/a | done |
| kiss-executor:a02ffc3 | kiss-executor | n/a | done |
| kiss-verificator:a2c8e8d | kiss-verificator | n/a | done |
| kiss-verificator:ab0c6e1 | kiss-verificator | n/a | done |
| kiss-executor:a251644 | kiss-executor | n/a | done |
| kiss-executor:a83d4e5 | kiss-executor | n/a | done |
| kiss-executor:a53638f | kiss-executor | 248s | done |
| kiss-verificator:aab024a | kiss-verificator | 84s | done |
| Explore:a6631e9 | Explore | n/a | done |
| kiss-executor:a589678 | kiss-executor | n/a | done |
| kiss-verificator:ac527a6 | kiss-verificator | n/a | done |
| kiss-executor:a33b3ab | kiss-executor | 56s | done |
| kiss-verificator:a56cb3c | kiss-verificator | 37s | done |
| Explore:aca7c62 | Explore | n/a | done |
| kiss-executor:a066ac3 | kiss-executor | 57s | done |
| kiss-verificator:a9db67f | kiss-verificator | 59s | done |

## Artifacts Produced

_No workspace path provided._


## Scenario Steps

| # | Step | Duration | Status | Detail |
|---|------|----------|--------|--------|
| 1 | step-1-greet | 8.5s | PASS | lang=en, text=How are you? |
| 2 | step-2-respond | 10.0s | PASS | response=I'm doing well, thanks for asking! I'm ready to help with yo |

## Acceptance Criteria

| AC | Result | Detail |
|----|--------|--------|
| AC-1 | PASS | Step 1 exit code is 0 |
| AC-2 | PASS | Step 1 output is non-empty |
| AC-3 | PASS | Language detected: English |
| AC-4 | PASS | session_id is non-empty string |
| AC-5 | PASS | Step 2 exit code is 0 |
| AC-6 | PASS | Step 2 output is non-empty |

## Consumption

| Metric | Value |
|--------|-------|
| Duration (API) | 5.1s (0.1min) |
| Duration (API calls only) | 4.9s |
| Turns | 1 |
| Total cost | $0.0535 |
| Stop reason | end_turn |
| Input tokens | 10 |
| Cache (create/read) | 41,978 / 0 |
| Output tokens | 198 |

## Diagnosis

_No diagnosis provided._

## Workspace

- **Path**: ``
- **Preserved**: no (cleaned up)
