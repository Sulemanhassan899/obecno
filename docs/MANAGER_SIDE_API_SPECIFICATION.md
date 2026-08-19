# Manager Side — API Specification (Module-wise)

Base: `https://app.obecno.com/` + `apiVersion` default `/api/v1`  
Example: `https://app.obecno.com/api/v1/manager/overview`

Auth: same as employee (`Authorization` from `TokenService`). 401 → logout.

Standard envelope (matches existing `ApiResponse`):

```json
{
  "success": true,
  "message": "optional",
  "data": {}
}
```

Dates: `YYYY-MM-DD`. Times: `HH:mm:ss` (24h) **and** ISO `occurred_at_iso`.  
Duration: server computes `working_minutes` and `working_duration_label` (`"8h 05m"`).  
Formula: `(check_out - check_in) - total_break_time`.

---

## How this maps to the product

| Manager module | New manager APIs? | Notes |
| --- | --- | --- |
| Clock (manager check-in) | No | Reuse employee Clock APIs |
| Attendance (manager’s own history) | No | Reuse employee Attendance APIs |
| Alerts | No | Same as employee; no product API yet |
| Settings | No | Reuse employee profile / devices / legal |
| Overview dashboard | **Yes** | Counts + live employee list |
| Employees | **Yes** | List, invite, edit, deactivate |
| Locations | **Yes** | CRUD + geofence + policy |
| Attendance of team | **Yes** | Multi-session, flags, manager edit |
| Devices of team | **Yes** | Approve / reject |
| Filters / search | **Yes** | Status + locations; search can be query on list APIs |
| Call / WhatsApp / Email / SMS | No | Use phone/email from employee profile |

Existing unused constants that **must not** be silently reused for manager:

| Constant | Path | Why not |
| --- | --- | --- |
| `companyEmployees` | `/employee/company-employees` | Employee-scoped; no manager fields (flags, live status, invite) |
| `teamLeaves` / `teamLeavesReview` | `/employee/team-leaves*` | Leave review only; dashboard “On Leaves” still needs a contract |
| `employeeDashboard` | `/employee/dashboard` | Self dashboard, not team |

Proposed prefix for all new endpoints: **`/manager/...`**.

---

# 0. Shared enums (use these strings everywhere)

### Live attendance status (`live_status`) — dashboard row + status filter

| Value | UI |
| --- | --- |
| `all` | All Status (filter only, not a row status) |
| `present` | Present Today |
| `working` | Active / Working |
| `break` | On Break |
| `late` | Late Check-In |
| `early_checkin` | Early Check-In (filter) |
| `early_checkout` | Early Check-Out (filter) |
| `absent` | Absent |
| `leave` | On Leave |
| `none` | Dash `–` (no punch / not expected) |

### Account status (`account_status`) — All Employees screen

| Value | UI |
| --- | --- |
| `active` | Active (no badge, or Active) |
| `pending` | Invited, not joined / not verified |
| `disabled` | Deactivated by manager |
| `deleted` | Soft-deleted |
| `approval_pending` | **Missing in UI** — employee waiting manager approval to join |

### Event type (`type`) — timeline (same as employee details)

`checkin` | `checkout` | `breakout` (break start) | `breakin` (break end)

### Attendance flags (booleans on employee row **and** on each punch)

| Field | Current dummy UI | Meaning to confirm |
| --- | --- | --- |
| `is_edited` | pencil | Attendance was manually edited |
| `is_outofrange` | location pin | Punch outside geofence |
| `is_exclamation` | red triangle (`warningred`) | **Needs product explanation** |
| `is_grey_exclamation` | grey warning (`warning`) | **Needs product explanation** |
| `is_circle_exclamation` | info alert (`infoalert`) | **Needs product explanation** |
| `is_notregistereddevice` | **Missing in UI** | Punch from unregistered / unapproved device |

---

# 1. Clock / Attendance / Alerts / Settings (manager as employee)

No new APIs. Manager uses the same endpoints as employee for **their own** punches, history, profile, devices, terms, privacy.

See `docs/EMPLOYEE_SIDE_SPECIFICATION.md` §21.

| Method | Path | Used for |
| --- | --- | --- |
| POST | `/employee/attendance` | Manager check-in / out / break |
| GET | `/employee/attendance` | Own history |
| GET | `/employee/attendance/details` | Own day timeline |
| POST | `/employee/attendance/edit` | Own edit **request** (pending approval) |
| GET | `/employee/profile` | Own settings |
| GET / POST / DELETE | `/employee/devices` | Own linked devices |

Manager **editing a team member’s attendance** is a different API (direct apply). Do not reuse `/employee/attendance/edit`.

---

# 2. Overview Module (Main Dashboard)

## 2.1 GET Dashboard (counts + filtered employee list)

**This is the primary Overview API.** One call should feed cards, filters, and the employee list.

`GET /manager/overview`

### Query

| Param | Type | Default | Notes |
| --- | --- | --- | --- |
| `date` | `YYYY-MM-DD` | today | Date filter |
| `location_ids[]` | string[] | all locations | Empty / omit = all |
| `status` | enum | `all` | See `live_status` |
| `q` | string | — | Search by employee name |
| `page` | int | 1 | |
| `page_size` | int | 20 | |

### Response `data`

```json
{
  "date": "2026-08-19",
  "filters": {
    "location_ids": ["1", "2"],
    "status": "all",
    "q": null
  },
  "counts": {
    "present_today": 33,
    "present_today_denominator": 40,
    "active_employees": 28,
    "on_break": 4,
    "late_check_in": 6,
    "absent": 5,
    "on_leave": 2,
    "total_employees": 40,
    "total_active_employees": 36,
    "pending_employees": 3,
    "disabled_employees": 1,
    "approval_pending_employees": 0
  },
  "employees": [
    {
      "id": "12",
      "name": "Ava Montgomery",
      "role": "CEO",
      "photo_url": "https://...",
      "phone": "+9715...",
      "email": "ava@company.com",
      "location_id": "1",
      "location_name": "Head Office",
      "account_status": "active",
      "badge": "owner",
      "live_status": "working",
      "check_in_time": "09:02:00",
      "check_in_label": "09:02 AM",
      "leave_duration_label": null,
      "flags": {
        "is_edited": false,
        "is_outofrange": false,
        "is_exclamation": false,
        "is_grey_exclamation": false,
        "is_circle_exclamation": false,
        "is_notregistereddevice": false
      }
    },
    {
      "id": "18",
      "name": "Shea Trantow",
      "role": "Designer",
      "photo_url": null,
      "phone": null,
      "email": "shea@company.com",
      "location_id": "1",
      "location_name": "Head Office",
      "account_status": "active",
      "badge": null,
      "live_status": "leave",
      "check_in_time": null,
      "check_in_label": null,
      "leave_duration_label": "5 Days",
      "flags": {}
    },
    {
      "id": "21",
      "name": "Jonas Janak",
      "role": "Manager",
      "photo_url": null,
      "phone": null,
      "email": "jonas@company.com",
      "location_id": "2",
      "location_name": "North Office",
      "account_status": "active",
      "badge": "manager",
      "live_status": "none",
      "check_in_time": null,
      "check_in_label": "–",
      "leave_duration_label": null,
      "flags": {}
    }
  ],
  "pagination": {
    "page": 1,
    "page_size": 20,
    "total": 40
  }
}
```

### Count mapping (UI cards)

| UI label | Field | Recommended meaning |
| --- | --- | --- |
| Today Present `33/40` | `present_today` / `present_today_denominator` | **33** = employees who checked in on `date`. **40** = employees assigned to selected location(s) who are **expected to work that day** (exclude disabled, deleted, not-working weekday, already-on-leave). **Needs product confirmation.** |
| Active Employees | `active_employees` | Currently clocked in and not on break (`live_status = working`) |
| On Break | `on_break` | `live_status = break` |
| Late Check-In | `late_check_in` | First check-in after policy + grace |
| Absent | `absent` | Expected to work, no check-in, not on leave |
| On Leaves | `on_leave` | Approved leave covering `date` |
| Total Employees | `total_employees` | All non-deleted accounts in filter |
| Total Active Employees | `total_active_employees` | `account_status = active` |
| Pending Employees | `pending_employees` | Invited, not joined / not verified |
| Disabled Employees | `disabled_employees` | Deactivated by manager |

`badge`: `owner` | `manager` | `you` | `null`

`leave_duration_label`: required when `live_status = leave` (e.g. `"5 Days"`). Also send `leave_start` / `leave_end` if available.

---

## 2.2 GET Status catalog (filter bottom sheet)

`GET /manager/filters/statuses`

Source: company policy. If policy does not define a subset, return the full UI list.

```json
{
  "statuses": [
    { "id": "all", "label": "All Status", "icon_key": "all" },
    { "id": "present", "label": "Present Today", "icon_key": "present" },
    { "id": "working", "label": "Active / Working", "icon_key": "working" },
    { "id": "break", "label": "On Break", "icon_key": "break" },
    { "id": "late", "label": "Late Check-In", "icon_key": "late" },
    { "id": "early_checkin", "label": "Early Check-In", "icon_key": "early_checkin" },
    { "id": "early_checkout", "label": "Early Check-Out", "icon_key": "early_checkout" },
    { "id": "absent", "label": "Absent", "icon_key": "absent" }
  ]
}
```

Apply / Reset are client-only. Reset → `status=all` and refetch Overview.

---

## 2.3 GET Locations for filters

Can be the same as **§11 GET All Locations**. Filter sheet only needs:

```json
{
  "locations": [
    { "id": "1", "name": "Head Office", "address": "...", "is_default": true }
  ]
}
```

If `locations.length == 1` → UI shows Single Location Sheet (client).  
Reset → omit `location_ids` (all).  
Apply → refetch Overview with selected ids.

---

## 2.4 Search

No dedicated search API. Pass `q` on Overview / All Employees.

Recent searches: **local device storage**, not backend.  
Empty result: client shows “Employee Not Found” when `employees = []` and `q` is set.

---

# 3. Employee Detail Sheet (tap row on dashboard)

## 3.1 GET Employee day attendance (multi-session)

`GET /manager/employees/{employee_id}/attendance/details?date=YYYY-MM-DD`

Same shape as employee `GET /employee/attendance/details`, plus location name and computed duration. **Required** for multiple check-ins / breaks.

```json
{
  "employee_id": "12",
  "employee_name": "Ava Montgomery",
  "role": "CEO",
  "photo_url": "https://...",
  "phone": "+9715...",
  "email": "ava@company.com",
  "date": "2026-08-19",
  "attendance_id": 901,
  "location_id": "1",
  "location_name": "Head Office",
  "check_in": "09:02:00",
  "check_out": "17:07:00",
  "working_minutes": 425,
  "working_duration_label": "7h 05m",
  "break_minutes": 60,
  "live_status": "working",
  "flags": {
    "is_edited": true,
    "is_outofrange": false,
    "is_exclamation": false,
    "is_grey_exclamation": false,
    "is_circle_exclamation": false,
    "is_notregistereddevice": false
  },
  "attendance_details": [
    {
      "id": "1001",
      "type": "checkin",
      "attendance_date": "2026-08-19",
      "attendance_time": "09:02:00",
      "occurred_at_iso": "2026-08-19T09:02:00+05:00",
      "current_location": "Head Office",
      "lat": 24.4539,
      "lon": 54.3773,
      "is_outofrange": false,
      "is_notregistereddevice": false,
      "change_requests": []
    },
    {
      "id": "1002",
      "type": "breakout",
      "attendance_time": "13:00:00",
      "occurred_at_iso": "2026-08-19T13:00:00+05:00",
      "current_location": "Head Office"
    },
    {
      "id": "1003",
      "type": "breakin",
      "attendance_time": "14:00:00",
      "occurred_at_iso": "2026-08-19T14:00:00+05:00",
      "current_location": "Head Office"
    },
    {
      "id": "1004",
      "type": "checkout",
      "attendance_time": "17:07:00",
      "occurred_at_iso": "2026-08-19T17:07:00+05:00",
      "current_location": "Head Office"
    }
  ]
}
```

Empty day / leave / dash: return `attendance_details: []`, `check_in/out: null`, `working_minutes: 0`. Do not invent punches.

---

# 4. Edit Attendance (manager → team member)

Manager applies immediately (not a pending request). Set `is_edited = true` and keep audit history.

## 4.1 PUT / POST save day

`PUT /manager/employees/{employee_id}/attendance`

```json
{
  "date": "2026-08-19",
  "attendance_id": 901,
  "location_id": "1",
  "check_in": "09:00:00",
  "check_out": "17:00:00",
  "reason": "optional"
}
```

If the day has multiple sessions, prefer sending the full timeline:

```json
{
  "date": "2026-08-19",
  "attendance_id": 901,
  "location_id": "1",
  "events": [
    { "id": "1001", "type": "checkin", "time": "09:00:00" },
    { "id": "1002", "type": "breakout", "time": "13:00:00" },
    { "id": "1003", "type": "breakin", "time": "13:45:00" },
    { "id": "1004", "type": "checkout", "time": "17:00:00" }
  ]
}
```

### Response

Same body as **§3.1** (refreshed day), plus `message`.  
Server must recompute `working_duration_label`.

Share arrow on the edit sheet is client-only (share text/image). No API.

---

# 5. Employee Profile / Actions Panel

## 5.1 GET employee profile (full)

`GET /manager/employees/{employee_id}`

Feeds: info sheet, call/message/WhatsApp/email, account edit, default locations, per-employee timings.

```json
{
  "id": "12",
  "name": "Ava Montgomery",
  "role": "CEO",
  "photo_url": "https://...",
  "email": "ava@company.com",
  "phone": "+971555123456",
  "company_id": "1234567890",
  "address": "Al Wasl Road, Dubai",
  "account_status": "active",
  "badge": "owner",
  "joining_date": "2024-03-01",
  "department": "Operations",
  "locations": [
    { "id": "1", "name": "Head Office", "is_default": true },
    { "id": "2", "name": "South Office", "is_default": false }
  ],
  "schedule": {
    "check_in": "08:00:00",
    "check_out": "17:00:00",
    "grace_minutes": 5,
    "working_days": ["monday", "tuesday", "wednesday", "thursday", "friday"],
    "week_start_day": "monday",
    "hours_per_day": "08:00",
    "hours_per_week": "40:00",
    "working_week_enabled": true,
    "max_break_minutes": 60,
    "break_location_tracking": true
  }
}
```

Call / WhatsApp / Email / SMS: **no API**. Use `phone` / `email`.

---

## 5.2 PATCH employee account fields (pen icon)

`PATCH /manager/employees/{employee_id}`

```json
{
  "email": "new@company.com",
  "phone": "+9715...",
  "company_id": "1234567890",
  "address": "Al Wasl Road, Dubai"
}
```

Send only changed keys. Response: full **§5.1** object.

---

## 5.3 PUT employee default locations

`PUT /manager/employees/{employee_id}/locations`

```json
{
  "location_ids": ["1", "3"],
  "default_location_id": "1"
}
```

Response: `{ "locations": [ ... ] }` same as in profile.

Confirm-location-change dialog is client-only; API runs after confirm.

---

## 5.4 PUT employee schedule (check-in/out, working days, break)

Can be three endpoints or one. Prefer one:

`PUT /manager/employees/{employee_id}/schedule`

```json
{
  "check_in": "08:00:00",
  "check_out": "17:00:00",
  "grace_minutes": 5,
  "working_days": ["monday", "tuesday", "wednesday", "thursday", "friday"],
  "week_start_day": "monday",
  "hours_per_day": "08:00",
  "hours_per_week": "40:00",
  "working_week_enabled": true,
  "max_break_minutes": 60,
  "break_location_tracking": true
}
```

`working_week_enabled`: when `false`, location/employee is treated as non-working (no absent). **Needs product confirmation.**

Response: `schedule` object.

Alternatively split to match the three sheets:

| Sheet | Endpoint |
| --- | --- |
| Check-In / Check-Out Time | `PUT .../schedule/timings` |
| Working Days | `PUT .../schedule/working-days` |
| Break Timing | `PUT .../schedule/break` |

---

## 5.5 POST reset password

`POST /manager/employees/{employee_id}/reset-password`

Body: `{}` (or `{ "send_email": true }`)

```json
{ "success": true, "message": "Reset link sent to ava@company.com" }
```

---

## 5.6 PATCH deactivate / reactivate

`PATCH /manager/employees/{employee_id}/status`

```json
{ "status": "disabled" }
```

Allowed: `active` | `disabled`. Deleted uses **§8.5**.

Response: `{ "id": "12", "account_status": "disabled" }`

---

# 6. Linked Devices (manager on a team member)

Employee self-list is `GET /employee/devices`. Manager needs the **same fields** for another user, plus approve/reject.

## 6.1 GET devices

`GET /manager/employees/{employee_id}/devices`

```json
{
  "devices": [
    {
      "id": "55",
      "device_id": "abc",
      "name": "iPhone 15",
      "model": "iPhone 15",
      "platform": "ios",
      "os": "iOS",
      "os_version": "18.0",
      "app_version": "1.0.0",
      "ip_address": "1.2.3.4",
      "timezone": "Asia/Dubai",
      "approval_status": "pending",
      "is_current": false,
      "requested_at": "2026-08-18T10:00:00Z",
      "last_active": null,
      "actioned_by": null
    }
  ]
}
```

`approval_status`: `approved` | `pending` | `rejected` | `blocked`  
(same as `DeviceModel`)

## 6.2 POST approve / reject / block

`POST /manager/employees/{employee_id}/devices/{device_id}/review`

```json
{ "action": "approve" }
```

`action`: `approve` | `reject` | `block`

Response: updated device object (`approval_status`, `actioned_by` = current manager name).

---

# 7. Overview → All Employees Screen

## 7.1 GET all employees (directory, not live attendance)

`GET /manager/employees`

### Query

| Param | Default |
| --- | --- |
| `location_id` | all |
| `account_status` | all (`active`,`pending`,`disabled`,`deleted`) |
| `q` | name search |
| `page` / `page_size` | 1 / 20 |

### Response

```json
{
  "counts": {
    "total_employees": 40,
    "active_employees": 36,
    "pending_employees": 3,
    "disabled_employees": 1,
    "deleted_employees": 2,
    "approval_pending_employees": 0
  },
  "employees": [
    {
      "id": "4",
      "name": "Mia Harper",
      "role": "Logistics Coordinator",
      "photo_url": null,
      "location_id": "3",
      "location_name": "South Office",
      "account_status": "pending",
      "badge": null
    }
  ],
  "pagination": { "page": 1, "page_size": 20, "total": 40 }
}
```

No check-in time on this screen. Status badge = `account_status` only.

---

# 8. Add Employee (invite)

## 8.1 GET invite link

`GET /manager/employees/invite-link`

Optional `location_id`.

```json
{
  "invite_url": "https://app.obecno.com/join?token=...",
  "expires_at": "2026-08-26T00:00:00Z"
}
```

Share button is client-side (share sheet). Clear does not regenerate the link.

## 8.2 POST send invite(s)

`POST /manager/employees/invite`

```json
{
  "invites": [
    { "email": "new@company.com", "location_id": "1" },
    { "email": "two@company.com", "location_id": "2" }
  ]
}
```

`location_id` required per row.

### Response

```json
{
  "sent": [
    { "email": "new@company.com", "employee_id": "99", "account_status": "pending" }
  ],
  "failed": [
    { "email": "bad@", "error": "Invalid email" }
  ]
}
```

UI: Invite Sent dialog → Continue (client navigation). No extra API.

## 8.3 Employee approval (missing in UI — still need API)

If join requires manager approval:

`GET /manager/employees?account_status=approval_pending`

`POST /manager/employees/{id}/approval`

```json
{ "action": "approve" }
```

`action`: `approve` | `reject`

**Needs product:** is this a real flow, or is invite+verify enough?

---

# 9. Employee Detail Screen (full page / attendance history)

Reuse employee history shape, scoped to `{employee_id}`.

## 9.1 GET monthly history + metrics

`GET /manager/employees/{employee_id}/attendance?month=YYYY-MM`

```json
{
  "month": "2026-08",
  "month_label": "August 2026",
  "metrics": {
    "working_days": 18,
    "total_working_days": 22,
    "leaves": 2,
    "late_check_in": 6,
    "late_check_out": 2,
    "absents": 2,
    "absent_or_leaves": 4
  },
  "days": [
    {
      "date": "2026-08-19",
      "attendance_id": 901,
      "day_status": "present",
      "check_in": "09:02:00",
      "check_out": "17:07:00",
      "break_minutes": 60,
      "working_minutes": 425,
      "working_duration_label": "7h 05m",
      "is_holiday": false,
      "is_weekend": false,
      "is_leave": false,
      "is_edited": true,
      "flags": { "is_outofrange": false }
    }
  ]
}
```

`day_status`: `present` | `absent` | `leave` | `holiday` | `weekend` | `none`

Tap a day → **§3.1** details.  
Edit → **§4**. Same sheets as dashboard.

Optional calendar dots:

`GET /manager/employees/{employee_id}/calendar?month=YYYY-MM`

Same idea as `/employee/calendar` (`month_label`, `attendance_dates`).

---

# 10. Locations (Overview dashboard + All Locations)

## 10.1 GET all locations

`GET /manager/locations`

Query: `date` (for present/total that day), default today.

```json
{
  "locations": [
    {
      "id": "1",
      "name": "Head Office",
      "address": "Bailey St, Stafford ST17 4BG, Birmingham",
      "photo_url": "https://...",
      "latitude": 52.806,
      "longitude": -2.116,
      "radius_meters": 150,
      "is_default": true,
      "is_active": true,
      "allow_checkin_anywhere": false,
      "present_today": 33,
      "total_employees": 40,
      "late_check_ins": 10,
      "created_by": "Ava Montgomery",
      "created_at": "2026-01-20"
    }
  ]
}
```

UI card: office name, address, image, `present_today/total_employees`, late count.

---

# 11. Location Detail

## 11.1 GET location

`GET /manager/locations/{location_id}?date=YYYY-MM-DD`

```json
{
  "id": "1",
  "name": "Head Office",
  "address": "...",
  "photo_url": "...",
  "latitude": 52.806,
  "longitude": -2.116,
  "radius_meters": 150,
  "is_active": true,
  "allow_checkin_anywhere": false,
  "present_today": 33,
  "total_employees": 40,
  "late_check_ins": 10,
  "schedule": {
    "check_in": "08:00:00",
    "check_out": "17:00:00",
    "grace_minutes": 5,
    "working_days": ["monday", "tuesday", "wednesday", "thursday", "friday"],
    "week_start_day": "monday",
    "hours_per_day": "08:00",
    "hours_per_week": "40:00",
    "working_week_enabled": true,
    "max_break_minutes": 60,
    "break_location_tracking": true
  },
  "today_employees": [ "/* same objects as Overview employees, for this location */" ]
}
```

Employee tab: `today_employees` **or** `GET /manager/overview?location_ids[]={id}`.  
Do not duplicate if Overview already covers it.

---

# 12. Location configuration

## 12.1 PUT location (name, map, radius, allow anywhere)

`PUT /manager/locations/{location_id}`

```json
{
  "name": "Head Office",
  "address": "Bailey St, Stafford ST17 4BG",
  "latitude": 52.806,
  "longitude": -2.116,
  "radius_meters": 150,
  "allow_checkin_anywhere": false,
  "photo": null
}
```

Map screen saves lat/lng/address here. Response: full location.

Photo: `POST /manager/locations/{id}/photo` multipart `photo` (same pattern as `/employee/profile/photo`).

## 12.2 PUT location schedule

`PUT /manager/locations/{location_id}/schedule`

Same body as **§5.4**. Location policy is the default; employee schedule overrides it.

## 12.3 PATCH deactivate

`PATCH /manager/locations/{location_id}/status`

```json
{ "is_active": false }
```

## 12.4 DELETE location

`DELETE /manager/locations/{location_id}`

```json
{ "success": true, "message": "Location deleted" }
```

Dialogs are client-only. Confirm then call API.

---

# 13. Add Location

## 13.1 POST create

`POST /manager/locations`

```json
{
  "name": "Warehouse B",
  "address": "optional until map setup",
  "latitude": null,
  "longitude": null,
  "radius_meters": 100
}
```

### Response

Created location object (with `id`). Then UI opens Add Members.

**Missing in current UI, required in API anyway:** `latitude`, `longitude`, `radius_meters`. Success dialog is client-side.

## 13.2 POST add members to location

`POST /manager/locations/{location_id}/members`

```json
{ "employee_ids": ["12", "18"] }
```

Response: `{ "added": 2, "location_id": "9" }`

GET candidates: `GET /manager/employees?q=` (exclude people already on this location if backend can).

---

# 14. Leaves (dashboard “On Leaves” + duration)

Dashboard counts need leave data even if Alerts has no API.

`GET /manager/leaves?date=YYYY-MM-DD`  
or include `on_leave` inside Overview counts (preferred) and `leave_duration_label` on the employee row.

If managers approve leave later:

| Method | Path |
| --- | --- |
| GET | `/manager/leaves?status=pending` |
| POST | `/manager/leaves/{id}/review` `{ "action": "approve" \| "reject" }` |

Declared unused employee paths `/employee/team-leaves*` must not be assumed to match this contract.

---

# 15. Attendance edit requests from employees (approval)

Employee already posts `POST /employee/attendance/edit` (pending). Manager inbox is **not in the Overview UI list** but is required if employees can request edits.

`GET /manager/attendance/change-requests?status=pending`

```json
{
  "requests": [
    {
      "id": "77",
      "employee_id": "12",
      "employee_name": "Ava Montgomery",
      "date": "2026-08-18",
      "attendancedetail_id": 1001,
      "old_value": "09:40:00",
      "new_value": "09:00:00",
      "status": "pending"
    }
  ]
}
```

`POST /manager/attendance/change-requests/{id}/review`

```json
{ "action": "approve" }
```

---

# API index (implement these)

### Overview

| # | Method | Path | Feeds |
| --- | --- | --- | --- |
| 1 | GET | `/manager/overview` | Dashboard counts + employee list + filters + search |
| 2 | GET | `/manager/filters/statuses` | Status bottom sheet |

### Employees

| # | Method | Path | Feeds |
| --- | --- | --- | --- |
| 3 | GET | `/manager/employees` | All Employees screen |
| 4 | GET | `/manager/employees/{id}` | Profile / actions / editable fields |
| 5 | PATCH | `/manager/employees/{id}` | Email, phone, company id, address |
| 6 | PATCH | `/manager/employees/{id}/status` | Deactivate / reactivate |
| 7 | PUT | `/manager/employees/{id}/locations` | Default office & locations |
| 8 | PUT | `/manager/employees/{id}/schedule` | Per-employee timings / days / break |
| 9 | POST | `/manager/employees/{id}/reset-password` | Reset password |
| 10 | GET | `/manager/employees/invite-link` | Invite via link |
| 11 | POST | `/manager/employees/invite` | Send invite email(s) |
| 12 | POST | `/manager/employees/{id}/approval` | Join approval (**if product wants it**) |

### Team attendance

| # | Method | Path | Feeds |
| --- | --- | --- | --- |
| 13 | GET | `/manager/employees/{id}/attendance` | History + metrics |
| 14 | GET | `/manager/employees/{id}/attendance/details` | Multi-session sheet |
| 15 | PUT | `/manager/employees/{id}/attendance` | Manager edit / add |
| 16 | GET | `/manager/employees/{id}/calendar` | Optional month dots |
| 17 | GET | `/manager/attendance/change-requests` | Employee edit inbox |
| 18 | POST | `/manager/attendance/change-requests/{id}/review` | Approve / reject edit |

### Devices

| # | Method | Path | Feeds |
| --- | --- | --- | --- |
| 19 | GET | `/manager/employees/{id}/devices` | Linked devices sheet |
| 20 | POST | `/manager/employees/{id}/devices/{device_id}/review` | Approve / reject / block |

### Locations

| # | Method | Path | Feeds |
| --- | --- | --- | --- |
| 21 | GET | `/manager/locations` | All Locations + location filter |
| 22 | GET | `/manager/locations/{id}` | Location detail + settings seed |
| 23 | POST | `/manager/locations` | Add location |
| 24 | PUT | `/manager/locations/{id}` | Map, name, radius, allow anywhere |
| 25 | PUT | `/manager/locations/{id}/schedule` | Check-in/out, days, break |
| 26 | PATCH | `/manager/locations/{id}/status` | Deactivate |
| 27 | DELETE | `/manager/locations/{id}` | Delete |
| 28 | POST | `/manager/locations/{id}/members` | Add members after create |
| 29 | POST | `/manager/locations/{id}/photo` | Office image |

### Leaves (if not folded into Overview)

| # | Method | Path |
| --- | --- | --- |
| 30 | GET | `/manager/leaves` |
| 31 | POST | `/manager/leaves/{id}/review` |

**Minimum to ship Overview + list + locations + invite:** APIs **1, 2, 3, 10, 11, 13, 14, 15, 21, 23, 28**.

---

# Open questions (do not invent in the app)

1. **Present Today `33/40`** — Confirm denominator: expected workers today vs all assigned vs all employees.
2. **Dash `–` in circle** — Confirm when `live_status = none` (weekend, not rostered, not yet punched, remote?).
3. **Three exclamation flags** — `is_exclamation` / `is_grey_exclamation` / `is_circle_exclamation` have no product meaning yet.
4. **`is_notregistereddevice`** — Missing in UI; still return it so Flutter can add a badge later.
5. **Employee approval** — Invite-only vs manager must approve join. API 12 is blocked on this.
6. **Two Add Location buttons** — Header `+` on All Locations and FAB/card CTA. Likely the same `POST /manager/locations`. Confirm they are not two different flows (create vs “setup map”).
7. **Working Day toggle** — `working_week_enabled`: does off mean “location closed” or “ignore attendance rules”?
8. **Manager edit vs employee request** — This spec assumes manager PUT applies immediately; employee POST stays pending until APIs 17–18.
9. **Hours per day vs hours per week** — UI has both; confirm server validates `hours_per_week ≈ hours_per_day × working_days`.
10. **Break only inside premises** — Enforced by `break_location_tracking` + geofence on `breakout`/`breakin`, not a separate API.

---

# Client-only (no API)

- Date picker default = today  
- Status / location Apply + Reset  
- Recent searches  
- Call, SMS, WhatsApp, Email composers  
- Share invite link / share attendance  
- Invite Sent dialog, delete/deactivate confirm dialogs, success dialogs  
- Single-location vs multi-location sheet layout  
- Two Add Location entry points (until product says they differ)

---

# API & response

Every response is wrapped as:

```json
{ "success": true, "message": "optional", "data": { } }
```

`data` is shown below.

---

### GET `/manager/overview`

```json
{
  "date": "2026-08-19",
  "filters": { "location_ids": ["1"], "status": "all", "q": null },
  "counts": {
    "present_today": 33,
    "present_today_denominator": 40,
    "active_employees": 28,
    "on_break": 4,
    "late_check_in": 6,
    "absent": 5,
    "on_leave": 2,
    "total_employees": 40,
    "total_active_employees": 36,
    "pending_employees": 3,
    "disabled_employees": 1,
    "approval_pending_employees": 0
  },
  "employees": [
    {
      "id": "12",
      "name": "Ava Montgomery",
      "role": "CEO",
      "photo_url": "https://...",
      "phone": "+9715...",
      "email": "ava@company.com",
      "location_id": "1",
      "location_name": "Head Office",
      "account_status": "active",
      "badge": "owner",
      "live_status": "working",
      "check_in_time": "09:02:00",
      "check_in_label": "09:02 AM",
      "leave_duration_label": null,
      "flags": {
        "is_edited": false,
        "is_outofrange": false,
        "is_exclamation": false,
        "is_grey_exclamation": false,
        "is_circle_exclamation": false,
        "is_notregistereddevice": false
      }
    }
  ],
  "pagination": { "page": 1, "page_size": 20, "total": 40 }
}
```

---

### GET `/manager/filters/statuses`

```json
{
  "statuses": [
    { "id": "all", "label": "All Status", "icon_key": "all" },
    { "id": "present", "label": "Present Today", "icon_key": "present" },
    { "id": "working", "label": "Active / Working", "icon_key": "working" },
    { "id": "break", "label": "On Break", "icon_key": "break" },
    { "id": "late", "label": "Late Check-In", "icon_key": "late" },
    { "id": "early_checkin", "label": "Early Check-In", "icon_key": "early_checkin" },
    { "id": "early_checkout", "label": "Early Check-Out", "icon_key": "early_checkout" },
    { "id": "absent", "label": "Absent", "icon_key": "absent" }
  ]
}
```

---

### GET `/manager/employees`

```json
{
  "counts": {
    "total_employees": 40,
    "active_employees": 36,
    "pending_employees": 3,
    "disabled_employees": 1,
    "deleted_employees": 2,
    "approval_pending_employees": 0
  },
  "employees": [
    {
      "id": "4",
      "name": "Mia Harper",
      "role": "Logistics Coordinator",
      "photo_url": null,
      "location_id": "3",
      "location_name": "South Office",
      "account_status": "pending",
      "badge": null
    }
  ],
  "pagination": { "page": 1, "page_size": 20, "total": 40 }
}
```

---

### GET `/manager/employees/{id}`

```json
{
  "id": "12",
  "name": "Ava Montgomery",
  "role": "CEO",
  "photo_url": "https://...",
  "email": "ava@company.com",
  "phone": "+971555123456",
  "company_id": "1234567890",
  "address": "Al Wasl Road, Dubai",
  "account_status": "active",
  "badge": "owner",
  "joining_date": "2024-03-01",
  "department": "Operations",
  "locations": [
    { "id": "1", "name": "Head Office", "is_default": true },
    { "id": "2", "name": "South Office", "is_default": false }
  ],
  "schedule": {
    "check_in": "08:00:00",
    "check_out": "17:00:00",
    "grace_minutes": 5,
    "working_days": ["monday", "tuesday", "wednesday", "thursday", "friday"],
    "week_start_day": "monday",
    "hours_per_day": "08:00",
    "hours_per_week": "40:00",
    "working_week_enabled": true,
    "max_break_minutes": 60,
    "break_location_tracking": true
  }
}
```

---

### PATCH `/manager/employees/{id}`

Same response as `GET /manager/employees/{id}`.

---

### PATCH `/manager/employees/{id}/status`

```json
{ "id": "12", "account_status": "disabled" }
```

---

### PUT `/manager/employees/{id}/locations`

```json
{
  "locations": [
    { "id": "1", "name": "Head Office", "is_default": true },
    { "id": "3", "name": "Warehouse B", "is_default": false }
  ]
}
```

---

### PUT `/manager/employees/{id}/schedule`

```json
{
  "schedule": {
    "check_in": "08:00:00",
    "check_out": "17:00:00",
    "grace_minutes": 5,
    "working_days": ["monday", "tuesday", "wednesday", "thursday", "friday"],
    "week_start_day": "monday",
    "hours_per_day": "08:00",
    "hours_per_week": "40:00",
    "working_week_enabled": true,
    "max_break_minutes": 60,
    "break_location_tracking": true
  }
}
```

---

### POST `/manager/employees/{id}/reset-password`

```json
{ "message": "Reset link sent to ava@company.com" }
```

---

### GET `/manager/employees/invite-link`

```json
{
  "invite_url": "https://app.obecno.com/join?token=...",
  "expires_at": "2026-08-26T00:00:00Z"
}
```

---

### POST `/manager/employees/invite`

```json
{
  "sent": [
    { "email": "new@company.com", "employee_id": "99", "account_status": "pending" }
  ],
  "failed": [
    { "email": "bad@", "error": "Invalid email" }
  ]
}
```

---

### POST `/manager/employees/{id}/approval`

```json
{ "id": "99", "account_status": "active", "action": "approve" }
```

---

### GET `/manager/employees/{id}/attendance`

```json
{
  "month": "2026-08",
  "month_label": "August 2026",
  "metrics": {
    "working_days": 18,
    "total_working_days": 22,
    "leaves": 2,
    "late_check_in": 6,
    "late_check_out": 2,
    "absents": 2,
    "absent_or_leaves": 4
  },
  "days": [
    {
      "date": "2026-08-19",
      "attendance_id": 901,
      "day_status": "present",
      "check_in": "09:02:00",
      "check_out": "17:07:00",
      "break_minutes": 60,
      "working_minutes": 425,
      "working_duration_label": "7h 05m",
      "is_holiday": false,
      "is_weekend": false,
      "is_leave": false,
      "is_edited": true,
      "flags": { "is_outofrange": false }
    }
  ]
}
```

---

### GET `/manager/employees/{id}/attendance/details`

```json
{
  "employee_id": "12",
  "employee_name": "Ava Montgomery",
  "role": "CEO",
  "photo_url": "https://...",
  "phone": "+9715...",
  "email": "ava@company.com",
  "date": "2026-08-19",
  "attendance_id": 901,
  "location_id": "1",
  "location_name": "Head Office",
  "check_in": "09:02:00",
  "check_out": "17:07:00",
  "working_minutes": 425,
  "working_duration_label": "7h 05m",
  "break_minutes": 60,
  "live_status": "working",
  "flags": {
    "is_edited": true,
    "is_outofrange": false,
    "is_exclamation": false,
    "is_grey_exclamation": false,
    "is_circle_exclamation": false,
    "is_notregistereddevice": false
  },
  "attendance_details": [
    {
      "id": "1001",
      "type": "checkin",
      "attendance_date": "2026-08-19",
      "attendance_time": "09:02:00",
      "occurred_at_iso": "2026-08-19T09:02:00+05:00",
      "current_location": "Head Office",
      "lat": 24.4539,
      "lon": 54.3773,
      "is_outofrange": false,
      "is_notregistereddevice": false,
      "change_requests": []
    },
    {
      "id": "1002",
      "type": "breakout",
      "attendance_time": "13:00:00",
      "occurred_at_iso": "2026-08-19T13:00:00+05:00",
      "current_location": "Head Office"
    },
    {
      "id": "1003",
      "type": "breakin",
      "attendance_time": "14:00:00",
      "occurred_at_iso": "2026-08-19T14:00:00+05:00",
      "current_location": "Head Office"
    },
    {
      "id": "1004",
      "type": "checkout",
      "attendance_time": "17:07:00",
      "occurred_at_iso": "2026-08-19T17:07:00+05:00",
      "current_location": "Head Office"
    }
  ]
}
```

---

### PUT `/manager/employees/{id}/attendance`

Same response as `GET /manager/employees/{id}/attendance/details`.

---

### GET `/manager/employees/{id}/calendar`

```json
{
  "month": "2026-08",
  "month_label": "August 2026",
  "attendance_dates": ["2026-08-03", "2026-08-04", "2026-08-19"]
}
```

---

### GET `/manager/attendance/change-requests`

```json
{
  "requests": [
    {
      "id": "77",
      "employee_id": "12",
      "employee_name": "Ava Montgomery",
      "date": "2026-08-18",
      "attendancedetail_id": 1001,
      "old_value": "09:40:00",
      "new_value": "09:00:00",
      "status": "pending"
    }
  ]
}
```

---

### POST `/manager/attendance/change-requests/{id}/review`

```json
{
  "id": "77",
  "status": "approved",
  "action": "approve"
}
```

---

### GET `/manager/employees/{id}/devices`

```json
{
  "devices": [
    {
      "id": "55",
      "device_id": "abc",
      "name": "iPhone 15",
      "model": "iPhone 15",
      "platform": "ios",
      "os": "iOS",
      "os_version": "18.0",
      "app_version": "1.0.0",
      "ip_address": "1.2.3.4",
      "timezone": "Asia/Dubai",
      "approval_status": "pending",
      "is_current": false,
      "requested_at": "2026-08-18T10:00:00Z",
      "last_active": null,
      "actioned_by": null
    }
  ]
}
```

---

### POST `/manager/employees/{id}/devices/{device_id}/review`

```json
{
  "id": "55",
  "device_id": "abc",
  "name": "iPhone 15",
  "approval_status": "approved",
  "actioned_by": "Ava Montgomery"
}
```

---

### GET `/manager/locations`

```json
{
  "locations": [
    {
      "id": "1",
      "name": "Head Office",
      "address": "Bailey St, Stafford ST17 4BG, Birmingham",
      "photo_url": "https://...",
      "latitude": 52.806,
      "longitude": -2.116,
      "radius_meters": 150,
      "is_default": true,
      "is_active": true,
      "allow_checkin_anywhere": false,
      "present_today": 33,
      "total_employees": 40,
      "late_check_ins": 10,
      "created_by": "Ava Montgomery",
      "created_at": "2026-01-20"
    }
  ]
}
```

---

### GET `/manager/locations/{id}`

```json
{
  "id": "1",
  "name": "Head Office",
  "address": "Bailey St, Stafford ST17 4BG, Birmingham",
  "photo_url": "https://...",
  "latitude": 52.806,
  "longitude": -2.116,
  "radius_meters": 150,
  "is_active": true,
  "allow_checkin_anywhere": false,
  "present_today": 33,
  "total_employees": 40,
  "late_check_ins": 10,
  "schedule": {
    "check_in": "08:00:00",
    "check_out": "17:00:00",
    "grace_minutes": 5,
    "working_days": ["monday", "tuesday", "wednesday", "thursday", "friday"],
    "week_start_day": "monday",
    "hours_per_day": "08:00",
    "hours_per_week": "40:00",
    "working_week_enabled": true,
    "max_break_minutes": 60,
    "break_location_tracking": true
  },
  "today_employees": []
}
```

---

### POST `/manager/locations`

```json
{
  "id": "9",
  "name": "Warehouse B",
  "address": null,
  "photo_url": null,
  "latitude": null,
  "longitude": null,
  "radius_meters": 100,
  "is_default": false,
  "is_active": true,
  "allow_checkin_anywhere": false,
  "present_today": 0,
  "total_employees": 0,
  "late_check_ins": 0
}
```

---

### PUT `/manager/locations/{id}`

Same response as `GET /manager/locations/{id}`.

---

### PUT `/manager/locations/{id}/schedule`

```json
{
  "schedule": {
    "check_in": "08:00:00",
    "check_out": "17:00:00",
    "grace_minutes": 5,
    "working_days": ["monday", "tuesday", "wednesday", "thursday", "friday"],
    "week_start_day": "monday",
    "hours_per_day": "08:00",
    "hours_per_week": "40:00",
    "working_week_enabled": true,
    "max_break_minutes": 60,
    "break_location_tracking": true
  }
}
```

---

### PATCH `/manager/locations/{id}/status`

```json
{ "id": "1", "is_active": false }
```

---

### DELETE `/manager/locations/{id}`

```json
{ "message": "Location deleted" }
```

---

### POST `/manager/locations/{id}/members`

```json
{ "added": 2, "location_id": "9" }
```

---

### POST `/manager/locations/{id}/photo`

```json
{
  "id": "1",
  "photo_url": "https://app.obecno.com/storage/locations/1.jpg"
}
```

---

### GET `/manager/leaves`

```json
{
  "leaves": [
    {
      "id": "44",
      "employee_id": "18",
      "employee_name": "Shea Trantow",
      "start_date": "2026-08-15",
      "end_date": "2026-08-19",
      "duration_label": "5 Days",
      "status": "approved"
    }
  ]
}
```

---

### POST `/manager/leaves/{id}/review`

```json
{ "id": "44", "status": "approved", "action": "approve" }
```
