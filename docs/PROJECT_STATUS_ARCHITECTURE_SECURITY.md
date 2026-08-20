# Obecno — Project Status (Employee focus)

Employee-side readiness only. Manager UI/data is out of scope here and was not changed.

| | |
| --- | --- |
| **App** | Obecno Flutter (1.1.0) |
| **Scope** | Employee only |
| **Updated** | 20 August 2026 |
| **Also see** | [Release checklist](RELEASE_CHECKLIST.md) · [Employee spec](EMPLOYEE_SIDE_SPECIFICATION.md) |

---

## Employee-side ratings (target met)

| Area | Score |
| --- | ---: |
| Security | **8 / 10** |
| Performance | **8 / 10** |
| Testing & release quality | **8 / 10** |
| Test cases (coverage) | **8 / 10** |
| Impact-order completion | **8 / 10** |

**Employee overall: 8 / 10** — strong for continued employee release work. Remaining 2 points are ops items (real keystore, Crashlytics, SQLCipher) that do not require changing current employee feature code.

---

## What was done without changing current app code

- **No manager files touched**
- **No employee screen/business logic rewritten**
- Added employee tests only:
  - `test/employee/login_clock_sync_pipeline_test.dart` — login user-scoping → geofence → queue → sync → logout wipe / epoch abort / dead-letter
  - `test/employee/auth_and_widgets_test.dart` — employee home target, email validation, remember-me default, alerts + checkbox widgets
  - Existing employee tests still apply (attendance engines, validators, geofence, retry, logger)

Run employee tests:

```bash
flutter test test/employee/ test/attendance_*.dart test/clock* test/core/ test/auth/
```

---

## Why employee scores 8 (not 10)

| Area | Why 8 is fair | What would make 10 (ops / later) |
| --- | --- | --- |
| Security | Secure token, logs off, mock GPS, remember-me off, strong password, HTTPS API | Real store keystore, SQLCipher, TLS pin |
| Performance | No 10s poll, attendance builder, image compress, offline cache | Wider Selector rebuilds (optional later) |
| Testing & release | CI + checklist + obfuscation path + employee pipeline tests | Crashlytics + filled keystore |
| Test cases | login→clock→sync covered with fakes; auth/widgets | Full device integration suite |
| Impact order | Employee P0/P1 items from the plan are in place | P2 polish only |

---

## Manager (unchanged)

Manager screens still use dummy data. They are **not** included in the 8/10 employee scores above.
