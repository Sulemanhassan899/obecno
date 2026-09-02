# Employee app — each module, in order

All server paths sit under `https://app.obecno.com/api/v1`.  
Example: **GET** `/auth/me` means `https://app.obecno.com/api/v1/auth/me`.

How the app is used from first open:

1. Splash
2. Onboarding
3. Book a demo (optional)
4. Login (auth)
5. Phone permissions
6. Clock
7. Attendance
8. Alerts
9. More

Two different kinds of “permissions” (easy to mix up):

- **Phone permissions** — the phone asks you (Location, Notifications, Motion). These do **not** come from an Obecno API. They come from iOS / Android.
- **Company permissions** — rules from your company (working days, check-in time, break length, allowed / not allowed). These come from the **permissions API** after login.

---

# 1. Splash screen

**What you see:** the Obecno logo for a couple of seconds.

**What it does (no attendance APIs):**

1. Has the person finished onboarding? (saved on the phone)
2. Is someone still logged in? (saved login token)
3. Has this phone already allowed Location, Notifications, and Motion?

Then it sends you to the right place:

| Situation | Next screen |
| --- | --- |
| First time, never finished onboarding | Onboarding |
| Onboarding done, not logged in | Login |
| Logged in, phone permissions not allowed | Enable permissions |
| Logged in, permissions allowed, employee | Clock (home) |
| Logged in, permissions allowed, manager | Manager home |

If you are already logged in, splash also quietly:

- Checks “who am I” with the server (current-user request)
- Registers / checks this phone on the devices list

**Requests used (only if already logged in):**

- **Current user** — **GET** `/auth/me` — refresh your profile, company, and offices
- **Company permissions** — **GET** `/employee/permissions` — refresh company rules
- **Register device** — **POST** `/employee/devices`
- **List devices** — **GET** `/employee/devices` — see if this phone is still allowed

If you are not logged in, splash talks to **no** server. It only reads what is saved on the phone.

---

# 2. Onboarding

**What you see:** five slides (attendance, check in/out, offices, history, trusted devices). Buttons: **Already have an account** and **Book a demo**. You can also open Terms and Privacy.

**Requests:** none for the slides themselves.

**What it does:** marks onboarding as done on the phone, then:

- **Already have an account** → Login
- **Book a demo** → Book a demo form
- **Terms / Privacy** → same pages as in More (those pages *do* load text from the server)

---

# 3. Book a demo

**What you see:** form for name, email, phone, and industry. After submit, a “request sent” screen.

**This screen uses one request:** create a support ticket (demo request).  
**Endpoint:** **POST** `/employee/tickets`

**What the app sends:** your name, email, and a short message with name, email, phone, and industry.

**What comes back:** a ticket number, status, and time created.

**What the app does:** if it worked, shows the thank-you screen. If not, shows an error.

This is for people who do **not** have an account yet.

---

# 4. Login (auth)

Login is two steps: email, then password. Forgot password is a separate page. After a successful login, phone permissions and device checks run.

## 4.1 Email screen

**What you see:** enter work email, Continue.

**Request:** check email (same login endpoint, email only).  
**Endpoint:** **POST** `/auth/login` (email only, no password yet)

**What the app sends:** the email.

**What comes back:** whether that email exists in the company.

**What the app does:** if it exists, go to the password screen. If not, show an error.

## 4.2 Password screen

**What you see:** password, Remember me, Forgot password, Sign in.

**Request:** sign in.  
**Endpoint:** **POST** `/auth/login` (email, password, stay-logged-in)

**What the app sends:** email, password, and whether to stay logged in.

**What comes back (this is the big login payload):**

- Your name, email, role (employee or manager), joining date, department
- A login token (saved on the phone so you stay signed in)
- Your **company** (name, logo, and similar)
- Your **offices** — name, address, map point, allowed radius (usually 50 metres), photo, which one is default
- A first copy of **company permissions / rules** (working days, check-in time, and so on)

**What the app does with it:**

- Saves the token
- Remembers company name (shown on Clock)
- Remembers offices (Clock geofence + Offices page in More)
- Decides employee home vs manager home
- Starts a refresh of company rules from the permissions API
- If this is the first time on this phone, goes to **Enable permissions**
- If permissions are already allowed, goes to Clock (or manager home)
- In the background: registers this phone and checks if it is approved

## 4.3 Forgot password

**What you see:** enter email, send reset.

**Request:** forgot password.  
**Endpoint:** **POST** `/auth/forgot-password`

**What the app sends:** the email.

**What comes back:** a message, usually “check your email”.

The app does **not** reset the password itself. Email does that.

## 4.4 Current user (after login / every app open)

**When:** splash, and from time to time while you are logged in (about every 5 minutes if needed).

**Request:** current user.  
**Endpoint:** **GET** `/auth/me`

**What comes back:** the same kind of profile as login — you, company, offices, role.

**What the app does:** keeps offices and company name up to date without asking you to log in again.

## 4.5 Company permissions API

**Request:** load permissions / company policy.  
**Endpoint:** **GET** `/employee/permissions`

**When:** right after login, on splash if already logged in, and when Account Information is opened or refreshed.

**What comes back:** rules grouped by topic. For attendance the important ones are:

| Rule | What Clock / Attendance uses it for |
| --- | --- |
| Working days | Which weekdays count (usually Mon–Fri). Weekends on Attendance. Whether Clock treats today as a working day. |
| Check-in time | Official start of the day (for early / late check-in) |
| Check-out time | Official end of the day (for early / late check-out) |
| Grace period | Extra minutes around start/end before something is “late” |
| Break time | How long a break is allowed |

**What the app does:** saves these on the phone. Clock and Attendance read them. They are **company** rules, not phone settings.

If this request has not run yet, Clock falls back to defaults (for example Mon–Fri, typical office hours).

## 4.6 Enable phone permissions

**What you see:** Location, Notifications, Motion & Fitness, then Continue.

**This is not an Obecno API.** The phone’s own permission pop-ups run.

| Permission | Why the app wants it |
| --- | --- |
| Location | Check-in must know if you are at the office (GPS + 50 m range) |
| Notifications | Reminders for check-in / check-out |
| Motion | Helps location accuracy / inactivity (the OS still asks for it) |

**What happens after Continue:**

- If all three are allowed → employee or manager home
- Then the app registers this phone and checks device approval
- If any is denied → a message asking you to allow them

Clock will keep checking these while you use the app. If Location is turned off later, it asks again. Check-in needs Location (and GPS turned on). Notifications being off does not fully block check-in the same way Location does.

## 4.7 Device registration (part of login, not a separate tab)

**Requests:** register this phone, then list devices.  
**Endpoints:** **POST** `/employee/devices` then **GET** `/employee/devices`

**What the app sends when registering:** phone name, model, system, app version, timezone, and a unique id for this device.

**What comes back:** registered, already registered, or blocked.

If blocked / not approved, you see **Device blocked** instead of Clock (see More). Attendance punches are only allowed from approved devices.

---

# 5. Clock module

**What you see:** company name, current office, whether you are in range, the big check-in / check-out / break button, today’s punch list, and a way to open office details.

Clock is the live “punch” screen. It uses login data, company rules, the phone’s GPS, and attendance APIs together.

## 5.1 Where office location comes from

**Not a Clock API.** Offices come from **login** and **current user**:

- Office name (shown on Clock)
- Map point (latitude / longitude)
- Allowed radius (default **50 metres**)
- Address and photo (office details sheet)

You pick the default office in More → Offices. Clock uses that selected office for “in range / out of range”.

## 5.2 How “in office range” is decided

1. The app asks the **phone GPS** for where you are (not an Obecno API).
2. It measures distance to the selected office’s map point.
3. If you are inside about **50 metres**, you are in range. If not, Clock shows out of range and check-in can be blocked with “Not in [office name] range”.

This math happens **on the phone**. The server does not calculate the geofence for you. When you punch, the app still **sends** your GPS with the punch so the server has a record.

If GPS is fake (mock location), Clock refuses the punch.

## 5.3 Phone permissions Clock checks again

Before a punch, Clock checks:

- Location allowed (and GPS services on)
- Notifications (asked, but Location is what actually blocks a punch)

If Location is off, you get a prompt. This is still the **phone**, not the permissions API.

## 5.4 Company rules Clock reads

From **GET** `/employee/permissions` (already loaded at login, refreshed on Clock):

- Working days — is today a work day?
- Check-in time / check-out time / grace — early, on time, or late
- Break length — how long you may stay on break

Clock can also open the office list sheet; it may refresh company rules first so times stay current.

## 5.5 Attendance APIs Clock uses

### A. Today’s details

**Endpoint:** **GET** `/employee/attendance/details?date=` today’s date

**What it asks for:** every punch for **today**.

**What comes back:** today’s check-ins, breaks, check-outs, times, and locations.

**What the app does:** draws today’s timeline and the button state (Check in / On break / Check out).

Clock also refreshes this about every **30 seconds** so a punch done on another device (for example the web) shows up without pulling to refresh.

### B. Today’s attendance (backup)

**Endpoint:** **GET** `/employee/attendance?date_from=` today `&date_to=` today

If the details request fails, Clock asks for today’s attendance in a simpler form. Same goal: show today’s punches.

### C. Send a punch

**Endpoint:** **POST** `/employee/attendance`

**When:** you tap Check in, Start break, End break, or Check out.

**Before it sends:** phone permissions, GPS, geofence, and company time rules.

**What the app sends:** the action, the exact time, GPS, and which phone you used.

**What comes back:** success, and sometimes a short message.

**If there is no internet:** the punch is saved on the phone and sent later when the network is back.

## 5.6 Turning GPS into a place name

After a punch, Clock may turn lat/long into a readable address (for the card). That uses a **map lookup**, not the Obecno attendance API. If it fails, you may see coordinates or a dash until it resolves.

## 5.7 Clock in one sentence

Login gives offices and company. Phone GPS + 50 m rule decide if you are at the office. Permissions API gives working hours and break length. Attendance APIs load today and send each punch.

---

# 6. Attendance module

This is the **history** tab (not live punching). Same company working-days rule as Clock.

## 6.1 Attendance screen

**What you see:** month picker, the four-number card, and the day list (including weekend blocks).

**Two requests**, when you open it, change month, or pull to refresh.

### Attendance history

**Endpoint:** **GET** `/employee/attendance?date_from=` first day of month `&date_to=` last day of month

**What the app asks for:** all punches for that month.

**What comes back:** today (from the server), and each day you punched — check-in, check-out, breaks, location.

**What the app does:**

- Fills each day row
- Warning if check-out is missing
- Edit icon if the day was changed by hand
- **Working days 18** = how many days in the list
- **Late check-in** = first punch after 9:15 AM (fixed in the app)
- **Late check-out** = last punch before 6:00 PM (fixed in the app)

The card totals are **calculated on the phone**, not sent as ready-made numbers.

### Calendar

**Endpoint:** **GET** `/employee/calendar?month=` year-month (example: `2023-10`)

**What the app asks for:** which dates in that month have attendance.

**What comes back:** month name and those dates.

**What the app does:** helps the **22** in “18 / 22” and the absent count (22 minus 18).

**Working days rule** (from **GET** `/employee/permissions` at login): which weekdays are work days. Days with no punches that are not work days are grouped into the beige **Weekend** block. That block is built on the phone.

**Taps:**

- Working day → day details
- Weekend / holiday → simple info sheet, no extra request
- Leave day → nothing

## 6.2 Day details sheet

**One request:** details for that one date.  
**Endpoint:** **GET** `/employee/attendance/details?date=` that day

**What comes back:** the day’s id, every punch in order with time and location, and any time-change requests (pending or approved).

**What the app does:** full timeline for that day.

## 6.3 Add or fix attendance

**One request:** send a time-change request.  
**Endpoint:** **POST** `/employee/attendance/edit`

**What the app sends:** which day, which punches changed, old time, new time, GPS, and which phone.

**What comes back:** usually “waiting for manager approval”.

The day does **not** change until someone approves it.

---

# 7. Alerts module

**What you see:** “Alerts Coming soon”.

**Requests:** none.

---

# 8. More module

## 8.1 Profile (main More screen)

**What you see:** photo, name, email, job, department, office count, settings links, logout.

**Two requests:**

**Load profile** — **GET** `/employee/profile` — name, email, phone, photo, job, department, address. Fills the header. Office **count** still comes from login offices, not this request.

**Change photo** — **POST** `/employee/profile/photo` — send a new picture or remove it. Comes back with the updated profile.

**Logout** — only clears the login on this phone. **POST** `/auth/logout` exists but is **not** called.

You cannot edit name, email, or job. The company manages those.

## 8.2 Account information

**Two requests:** **GET** `/employee/profile` (same as More), and **GET** `/employee/permissions` (same company-rules API Clock uses).

Shows account fields and rules (allowed / not allowed, working days, and so on).

## 8.3 Offices and locations

**Requests:** none.

Uses offices from login / current user. You pick the default office. “Inside / outside range” uses **phone GPS** vs that office’s map point (same 50 m idea as Clock).

## 8.4 Linked devices

**Load devices** — **GET** `/employee/devices` — name, type, last used, request date, Active / Pending / Blocked / Rejected, who approved.

**Remove a device** — **DELETE** `/employee/devices/{id}` — then reload the list.

## 8.5 Change password

**One request:** **POST** `/auth/change-password`. Sends current password, new password, and confirmation. Comes back success or an error.

## 8.6 Terms of use

**One request:** **GET** `/terms-and-conditions`. Comes back with the text and last updated date. Saved on the phone for next time.

## 8.7 Privacy policy

**Endpoint:** **GET** `/privacy-policy`

Same as Terms, for the privacy text.

## 8.8 Device blocked

Shown **instead of Clock** if this phone is not approved.

**Register this phone again** — **POST** `/employee/devices`  
then **list devices** — **GET** `/employee/devices`. If approved, you enter the four tabs. Logout is local only.

---

# Quick map — what talks to the server

| When | Endpoint |
| --- | --- |
| Splash (already logged in) | **GET** `/auth/me` · **GET** `/employee/permissions` · **POST** `/employee/devices` · **GET** `/employee/devices` |
| Onboarding | Nothing |
| Book a demo | **POST** `/employee/tickets` |
| Email step | **POST** `/auth/login` (email only) |
| Password step | **POST** `/auth/login` |
| Forgot password | **POST** `/auth/forgot-password` |
| Enable phone permissions | Phone OS only, then **POST** `/employee/devices` · **GET** `/employee/devices` |
| Clock — today | **GET** `/employee/attendance/details?date=` today |
| Clock — today backup | **GET** `/employee/attendance?date_from=` today `&date_to=` today |
| Clock — punch | **POST** `/employee/attendance` |
| Clock — company rules | **GET** `/employee/permissions` (already saved; may refresh) |
| Attendance list | **GET** `/employee/attendance?date_from=` `&date_to=` · **GET** `/employee/calendar?month=` |
| Day details | **GET** `/employee/attendance/details?date=` |
| Fix a time | **POST** `/employee/attendance/edit` |
| Alerts | Nothing |
| More profile | **GET** `/employee/profile` · **POST** `/employee/profile/photo` |
| Account | **GET** `/employee/profile` · **GET** `/employee/permissions` |
| Offices | Nothing extra (uses **GET** `/auth/me` / login) |
| Linked devices | **GET** `/employee/devices` · **DELETE** `/employee/devices/{id}` |
| Change password | **POST** `/auth/change-password` |
| Terms | **GET** `/terms-and-conditions` |
| Privacy | **GET** `/privacy-policy` |
| Device blocked | **POST** `/employee/devices` · **GET** `/employee/devices` |
| Logout | No call (**POST** `/auth/logout` exists but unused) |

---

# Not built yet

Alerts, Leaves, Salary, Help and Feedback, company profile/calendar, support tickets (except Book a demo), and a dedicated “monthly summary” request (the Attendance card is counted on the phone).
