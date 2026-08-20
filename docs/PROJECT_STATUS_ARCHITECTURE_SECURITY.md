# Obecno — Project Status

A simple status guide for the whole app: what is done, what is in progress, and what still needs to be done.

| | |
| --- | --- |
| **App** | Obecno Flutter app (version 1.1.0) |
| **Date** | 20 August 2026 |
| **For** | Developers, QA, design, product |
| **Also see** | [Employee spec](EMPLOYEE_SIDE_SPECIFICATION.md) · [Manager API spec](MANAGER_SIDE_API_SPECIFICATION.md) |

---

## Contents

1. [How to read this](#1-how-to-read-this)
2. [What the app is](#2-what-the-app-is)
3. [What is happening right now](#3-what-is-happening-right-now)
4. [Status at a glance](#4-status-at-a-glance)
5. [Architecture](#5-architecture)
6. [Security](#6-security)
7. [Performance](#7-performance)
8. [Tests by module](#8-tests-by-module)
9. [Release quality](#9-release-quality)
10. [What to do first](#10-what-to-do-first)

---

## 1. How to read this

Every item uses one of these labels:

| Label | Meaning |
| --- | --- |
| **Done** | Built and working |
| **In progress** | Being worked on now |
| **Partial** | Started, but not finished |
| **To do** | Not done yet |

**Rule:** Do not rebuild the app on a new architecture. Improve what we already have.

---

## 2. What the app is

Obecno is a **location-based attendance** app with two roles.

### Employee

| Screen | Status |
| --- | --- |
| Clock in / out (with GPS and offline support) | **Done** |
| Attendance history and edit request | **Done** |
| More — profile, devices, password, terms | **Done** |
| Alerts | **To do** (shows “Coming soon”) |
| Leaves / salary | **To do** |

### Manager

| Screen | Status |
| --- | --- |
| Clock (own punch — same as employee) | **Done** |
| Overview, Employees, Locations, Team attendance | **Partial** — screens exist, data is fake |
| Alerts | **To do** (shows “Coming soon”) |

### Shared (both roles)

Login, device approval, GPS geofence, offline punch queue, secure login token.

---

## 3. What is happening right now

Current work is **UI polish**, not security or tests.

- Text styles, buttons, dialogs, bottom sheets
- Onboarding and permission screen
- Location setup / map
- Attendance headers and filter chips

Keep this UI work in its own PR. Do not mix it with security or test work.

---

## 4. Status at a glance

| Area | Status | Notes |
| --- | --- | --- |
| Employee clock + offline sync | **Done** | Main path works |
| Employee attendance history | **Done** | Main path works |
| Login and device block | **Partial** | Works, but token refresh is missing |
| Manager screens | **Partial** | UI is ready, still uses dummy data |
| Alerts | **To do** | Placeholder only |
| Tests | **Partial** | Only 4 test files |
| Store release setup | **To do** | Still using example app id and debug keys |
| Auto-check on every PR (CI) | **To do** | Not set up |
| API logs in production | **To do** | Currently **on by default** — must turn off |

---

## 5. Architecture

How the code is organised today. **Keep this.** Do not switch to Bloc, Riverpod, or GetX.

### Folder map

```
lib/
  core/              shared tools (API, theme, login token)
  features/
    launch/          splash, onboarding, book a demo
    auth/            login and session
    clock/           clock in / out
    employee_module/ attendance, alerts, profile
    manager_module/  overview, team, employees, locations
  shared/            location, offline queue, bottom sheets
  widgets/           buttons, nav bars, fields
  demo/              fake manager data — not for production
```

### Data flow (Done)

```
Screen → Provider → Service → Repository → ApiClient → Server
```

Offline clock punches go to a local queue, then sync when the internet is back.

### Architecture status

| Item | Status | Action |
| --- | --- | --- |
| Feature folders | **Done** | Keep them |
| Login token in secure storage | **Done** | Keep it |
| Offline punch queue (per user) | **Done** | Keep it |
| Attendance saved on device (per user) | **Done** | Keep it |
| Logout clears local data | **Done** | Add a test so it cannot break |
| Manager real APIs | **To do** | Follow the manager API spec; stop using `lib/demo/` |
| One simple login API (`isLoggedIn` / `validate` / `logout`) | **To do** | Today this is split across 4 files |
| Dead commented-out code | **To do** | Delete it (git keeps history) |
| App routes under employee folder | **To do** | Move to a shared routes folder |
| Unused API names (leaves, salary, tickets) | **To do** | Build them or remove them |
| Wrong file name `overview_screen.dart.dart` | **To do** | Rename it |

---

## 6. Security

Do this **before** new features.

### Done

- App talks to the server over HTTPS
- Login token is stored securely (not in plain settings)
- Fake GPS is rejected
- Weak GPS (worse than 50m) is rejected
- Blocked devices cannot use the app
- Clock retries never double-punch (only GET requests retry)
- User A’s offline punches cannot sync as User B
- Logout clears token, queue, and attendance cache

### In progress

None. The current UI work does not change security.

### To do

| Priority | Problem | Fix |
| --- | --- | --- |
| High | API logs print passwords, tokens, and GPS | Turn logs **off** in production |
| High | Release app is signed with **debug** keys | Use a real store keystore |
| High | App id is `com.example.obecno` | Change to a real id, e.g. `com.obecno.app` |
| High | Login token cannot refresh | Add refresh; log out if it fails |
| High | “Remember me” is on even if the user never chose it | Default to **off** |
| High | Employee invite link uses `http://` | Use `https://` |
| Medium | Attendance database on the phone is not encrypted | Encrypt it |
| Medium | GPS saved in plain settings | Move coordinates to encrypted storage |
| Medium | App asks for extra Android permissions (Bluetooth, old storage) | Keep only what clock-in needs |
| Medium | No certificate pin | Pin the API domain |
| Medium | Password only checks length | Require strong passwords on change |
| Low | App code is easy to reverse | Obfuscate the release build |
| Low | Rooted phones can still clock in | Detect and block |
| Low | Sensitive screens can be screenshotted | Block if product requires it |

---

## 7. Performance

Make the app faster and use less battery.

### Done

- Network timeouts
- Cancel leftover work after logout
- Save attendance months on the device so the app does not refetch every time
- Employee tabs stay in memory (no full reload on tab switch)
- Clock works offline, then syncs

### In progress

UI widgets are being cleaned up (buttons, sheets). That helps a little. Lists and battery polling are unchanged.

### To do

| Problem | Fix |
| --- | --- |
| App checks permissions every **10 seconds** | Check only when the app opens or comes to the front |
| Long lists build every row at once | Use lazy lists (`ListView.builder`) |
| Whole screen rebuilds on small state changes | Rebuild only the widget that changed |
| Two state libraries in the project | Use only one |
| Very large screen files | Split into smaller widgets |
| Heavy JSON / database work on the UI thread | Move to a background thread |
| Unused packages (e.g. `cookie_jar`) | Remove them |
| Many lint rules are turned off | Turn the important ones back on |
| Profile photos uploaded at full size | Compress before upload |

---

## 8. Tests by module

We have **4 tests** today. Almost every module still needs tests.

Each module should cover: logic → API/repository → one screen.

### Already written

| File | Covers |
| --- | --- |
| `test/clock_approved_time_test.dart` | Clock time after a manager approves an edit |
| `test/attendance_session_times_test.dart` | First check-in / last check-out, multiple sessions |
| `test/attendance_change_request_test.dart` | Edit-request data sent to the server |
| `test/widget_test.dart` | App opens (weak — uses real app startup) |

### What to add

#### Core (API and tools)

- Token is sent on requests; not sent when logged out
- Failed GET retries; clock POST never retries
- Invalid session logs the user out
- Logs never print passwords or tokens
- Cancelled requests stop cleanly

#### Auth

- Login saves the token
- Failed login does not open the app
- Remember-me stays off unless chosen
- Logout clears queue and database even if one step fails
- Employee vs manager land on the right home screen

#### Launch

- Splash goes to onboarding, login, or home for the right reason
- Book-a-demo form sends the right data

#### Clock

- Fake GPS is blocked (**to do** — important)
- Punch outside the office is blocked
- Offline punch is saved with the correct user id
- Sync on reconnect does not double-punch
- Logout during sync does not apply old data

#### Employee attendance

- Cache does not mix User A and User B
- Late / absent / leave day types are correct

#### Employee more (profile, devices)

- Photo upload
- Weak password is rejected
- Unlink device
- Blocked device goes to the blocked screen

#### Alerts (both roles)

- Until the API exists: screen shows “Coming soon”
- After the API: list and open an alert

#### Manager

Write these **after** dummy data is replaced with real APIs:

- Overview counts
- Employee search and invite
- Location geofence save / delete
- Team attendance filters and manager edit

### Where to put new tests

```
test/
  core/       API, token, validators, logs
  auth/       login, session, logout
  clock/      GPS, sync, queue          ← 1 file already exists
  employee/   attendance                ← 2 files already exist
  manager/    overview, employees, locations
  widget/     smoke test, login screen
```

**Start with:** auth, clock GPS, offline queue, logout cleanup.  
**Then:** manager mapping, once live APIs exist.

---

## 9. Release quality

Checklist before putting the app on the Play Store / App Store.

| Item | Status |
| --- | --- |
| App version number | **Done** (1.1.0) |
| Unique store app id | **To do** |
| Real signing keys | **To do** |
| Logs off in production | **To do** |
| Hide / obfuscate release code | **To do** |
| Auto test on every pull request | **To do** |
| Pin package versions | **To do** |
| Crash reporting | **To do** |
| Separate dev / staging / production builds | **To do** |
| No dummy manager data in store build | **To do** |

Also:

- Privacy screens must match what the app actually collects (GPS, device, photos).
- The current smoke test should not start the real network. Use fakes.

---

## 10. What to do first

### High impact — do first

1. Turn off production API logs
2. Real app id + real signing keys
3. Token refresh (log out if it fails)
4. Remember-me default **off**
5. HTTPS on the invite link
6. Tests for fake GPS, logout cleanup, and queue user id
7. Do not ship manager dummy data as live data

### Medium impact — do next

1. Encrypt the on-device database
2. Stop the 10-second permission check
3. Remove unused Android permissions
4. Pin the server certificate
5. Strong passwords
6. Faster lists and fewer screen rebuilds
7. Turn important lints back on
8. Connect manager screens to real APIs
9. Auto-run analyze + tests on every PR

### Low impact — later

1. Obfuscation and crash reporting
2. Rooted-phone check
3. Screenshot block (if product wants it)
4. Dev / staging / production flavors
5. Remove unused packages
6. Alerts, leaves, salary product features
7. More screen-level widget tests

---

## Suggested plan

| When | What |
| --- | --- |
| **Now** | Keep UI polish in its own PR |
| **Week 1** | High-impact security + the tests listed above |
| **Week 2** | Battery poll, lints, faster lists |
| **After that** | Manager live APIs, then delete dummy data |

---

*Update the status labels in this file when a high-impact item is finished.*
