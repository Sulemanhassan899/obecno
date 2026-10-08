# Pass / fail rules (simple)

Use these four results only.

| Result | Meaning | Excel |
|--------|---------|--------|
| **pass** | Expected behavior happened (UI + data). | Online and/or Offline ticked; Tested ticked; status = success |
| **fail** | App did the wrong thing, crashed, wrong screen, bad copy, broken validation, data wrong. | Tested ticked; status = Failed; write bug in Bugs |
| **blocked** | Could not run the case (no login, no device, missing permission, API down, account not ready). | Tested not required; status = Development; explain in Notes |
| **skip** | Out of scope for this run (module not selected). | Leave empty |

## Online vs offline

- If the case needs internet: test **Online** when possible.
- If the case can work without internet: also test **Offline** (airplane mode or disable network).
- Tick only the modes you actually tested.

## When to stop a module

Stop the module early only if:

1. App crashes on open, or
2. Login is impossible, or
3. More than **5 fails** in the same module with the same root cause (log once, mark rest blocked with “same as CASE-ID”).

## Bug note format (Bugs column)

One short line:

`[severity] what happened → expected. screenshot: path`

Severity: `blocker` | `major` | `minor` | `polish`

Example:

`[major] Check-in toast missing after success → should show success toast. screenshot: qa/runs/2026-04-08/emp-clock-012.png`

## Screenshots

Save under `qa/runs/<run_id>/` as `<case_id>.png`.
