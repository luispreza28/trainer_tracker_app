Here’s a clean, copy-paste Product Requirements Document (PRD) for **Trainer Tracker**. It reflects what we’ve built so far and what’s next, and it’s structured so you (and Cursor) can execute against it.

---

# Product Requirements Document (PRD)

**Product:** Trainer Tracker
**Owners:** You (PM/Eng), Collaborators (Backend: Django/DRF, Frontend: Flutter)
**Last updated:** Aug 2025
**Status:** MVP shipped (web); incremental features in progress

---

## 1) Problem Statement

People trying to manage nutrition struggle to quickly log meals and see meaningful daily feedback. Existing apps often feel heavy, slow, or require too many steps. We need a fast, privacy-respecting tracker that makes barcode import, logging, and daily insights effortless.

---

## 2) Goals & Non-Goals

### Goals (MVP + Near-term)

- **Instant meal logging:** Import foods via barcode (OpenFoodFacts), log grams, see daily totals immediately.
- **Daily clarity:** TZ-aware **per-day summary** (kcal/macros/sodium) that matches the **per-day entries** list.
- **Frictionless auth:** Token stored locally; web dev runs smoothly; Android later.
- **Usability:** “Today/Yesterday” browsing + date picker driving both summary and meals.
- **Personalization:** Local goals (kcal/macros/sodium) with progress indicators.

### Non-Goals (for now)

- Social features, coaching, or meal plans.
- Complex micronutrient tracking.
- Multi-device profile sync (future).
- Payments/subscriptions.

---

## 3) Users & Personas

- **Self-trackers:** Want quick intake tracking and daily totals without ceremony.
- **Fitness-focused users:** Care about protein/carb/fat distribution; want fast add/edit flows.
- **Coaches (future):** May review client summaries (not in MVP scope).

---

## 4) Success Metrics (MVP)

- **T1:** Median time to log a meal (open → submit) ≤ **20s** for known barcodes.
- **T2:** API success rate (2xx) ≥ **99%** for POST/GET on meals; 4xx/5xx surfaced with clear messaging.
- **T3:** **Daily active logging** rate (DAL): ≥ **60%** of users who created a token log at least once in 7 days.
- **T4:** Per-day **summary totals match list aggregates** (0 discrepancies in test suite).
- **Perf:** P50 API latency ≤ **300ms** server-side for list/summary with 100 entries/day; P95 ≤ **800ms**.

---

## 5) Scope (MVP Feature Set)

### Must-Have

1. **Barcode Import (OFF)**

   - POST `/api/foods/import/barcode/<code>/` → creates `Food` + `Nutrients` if absent; idempotent.
   - Safe numeric coercion; `sugar` (not `sugars`); sodium mg.

2. **Meals CRUD**

   - POST `/api/meals/` (auth) with `food`, `quantity` (grams), `meal_time`, `notes?`.
   - GET `/api/meals/?date=YYYY-MM-DD&tz=Area/City` (auth) — per-day, TZ-aware.
   - PATCH `/api/meals/<id>/` (quantity), DELETE `/api/meals/<id>/`.

3. **Daily Summary (TZ-aware)**

   - GET `/api/meals/summary/?date=YYYY-MM-DD&tz=Area/City` (auth).
   - Totals for kcal/protein/carbs/fat/fiber/sugar/sodium; `entries` count.
   - **Invariant:** summary equals aggregate of list for same date/tz.

4. **Frontend (Flutter Web)**

   - Barcode screen: barcode input + import result; **Today’s Summary** + **Today’s Meals** cards.
   - **Date picker** drives both cards; “Today/Yesterday” shortcuts.
   - **Token settings** screen (save/clear) with return + refresh.
   - **Goals** screen (local): stores daily targets; summary shows progress bars.

5. **Auth**

   - DRF Token required; Flutter attaches `Authorization: Token <token>`; stored in `SharedPreferences`.

### Should-Have

- Edit grams in meals list (inline) and delete; auto-refresh summary.
- Robust snackbars/errors for 401/404/5xx and network edge cases.

### Nice-to-Have (Next)

- Android app: barcode scan (`mobile_scanner`), cleartext dev config.
- Server-synced goals/profile for multi-device consistency.
- Trends/weekly rollups; streaks; export CSV.

---

## 6) User Stories & Acceptance Criteria

### US-1: Import food by barcode

- **As a** user
- **I want** to enter a barcode and import a food’s nutrition facts
- **So that** I can log it quickly.
- **Acceptance:**

  - Given valid token, when I POST import with a known barcode, then `201` on first import, `200` on subsequent calls.
  - The created `Food` has mapped nutrients (kcal/protein/carbs/fat/fiber/**sugar**/sodium).
  - Errors from OFF show as `502` (lookup failed) or `404` (not found).

### US-2: Log a meal

- **As a** user
- **I want** to log `food + grams + when`
- **So that** my day’s totals update.
- **Acceptance:**

  - POST `/api/meals/` returns `201` with entry.
  - Summary totals change accordingly for the selected date.

### US-3: See today’s meals and totals (TZ-aware)

- **As a** user
- **I want** to browse a day’s meals and totals
- **So that** I understand daily intake.
- **Acceptance:**

  - GET list (date/tz) returns only that local day’s entries (half-open window `[start_local, next_day_local)`).
  - GET summary (same date/tz) matches the aggregated list exactly.

### US-4: Change grams or delete

- **As a** user
- **I want** to edit or remove an entry
- **So that** the day’s totals stay accurate.
- **Acceptance:**

  - PATCH updates `quantity`; summary refreshes.
  - DELETE removes item; summary refreshes.

### US-5: Set daily goals (local)

- **As a** user
- **I want** to set kcal/macros/sodium targets
- **So that** I see progress in the summary.
- **Acceptance:**

  - Goals persist locally; progress bars/percentages display when goal > 0.
  - Selecting a different date recalculates progress using that day’s totals.

---

## 7) UX / UI Requirements

- **Barcode screen:**

  - AppBar with token button; search/import area; date bar with calendar & Today/Yesterday & Refresh.
  - **Cards:** Summary (kcal/macros/sodium; units; progress vs goals), Meals list (name/brand, grams, totals; Edit/Delete).

- **Goals screen:**

  - 7 numeric fields; select-all on focus; Save + optional Reset.

- **States:** Loading, empty (“No meals yet”), error snackbars.
- **Accessibility:** High contrast, clear labels, keyboard navigation, large tap targets.

---

## 8) Data Model (Backend)

- **Food**: `id`, `name`, `brand`, `barcode`, `fdc_id?`, `serving_size?`, `serving_unit?`, `data_source` (“OFF”), `nutrients (FK)`
- **Nutrients**: `id`, `calories`, `protein`, `carbs`, `fat`, `fiber`, `sugar`, `sodium`
- **MealEntry**: `id`, `user (FK)`, `food (FK)`, `quantity (g)`, `meal_time (UTC)`, `notes?`

---

## 9) API (Contract Summary)

### Auth

- Header: `Authorization: Token <token>`

### Foods

- `GET /api/foods/?barcode=<code>` → find locally (200 or 404)
- `POST /api/foods/import/barcode/<code>/` → import from OFF via proxy (201 first, 200 thereafter)

### Meals

- `POST /api/meals/` → create meal
- `GET /api/meals/?date=YYYY-MM-DD&tz=Area/City` → per-day list (paginated)
- `PATCH /api/meals/<id>/` → update `quantity`
- `DELETE /api/meals/<id>/` → delete

**List item shape (subset):**

```json
{
  "id": 12,
  "food": 11,
  "food_name": "Thai peanut noodle kit...",
  "brand": "Simply Asia",
  "quantity": 100.0,
  "meal_time": "2025-08-18T17:38:40Z",
  "per100": {
    "calories": 385.0,
    "protein": 9.62,
    "carbs": 71.15,
    "fat": 7.69,
    "fiber": 1.9,
    "sugar": 13.46,
    "sodium": 288.0
  },
  "totals": {
    "calories": 385.0,
    "protein": 9.62,
    "carbs": 71.15,
    "fat": 7.69,
    "fiber": 1.9,
    "sugar": 13.46,
    "sodium": 288.0
  }
}
```

### Summary

- `GET /api/meals/summary/?date=YYYY-MM-DD&tz=Area/City`

```json
{
  "date": "2025-08-18",
  "timezone": "America/Los_Angeles",
  "entries": 4,
  "units": {
    "calories": "kcal",
    "protein": "g",
    "carbs": "g",
    "fat": "g",
    "fiber": "g",
    "sugar": "g",
    "sodium": "mg"
  },
  "totals": {
    "calories": 43120.0,
    "protein": 1077.44,
    "carbs": 7968.8,
    "fat": 861.28,
    "fiber": 212.8,
    "sugar": 1507.52,
    "sodium": 32256.0
  }
}
```

---

## 10) Technical Approach

- **Timezone helper:** `_utc_window_for_local_day(date, tz)` returns `(start_utc, end_utc)`, half-open window. Both list & summary use the same helper.
- **OFF client:** Clean mapping; robust to nulls; throw clear errors for 404/502.
- **DRF:** Token auth; viewsets thin; business logic factored; `select_related('food__nutrients')`.
- **Flutter:** `http` client with token header; snackbars; date picker; `SharedPreferences` for token/goals; `intl` for date formatting.

---

## 11) Security & Privacy

- **Secrets:** `.env` ignored; rotate on leak; no secrets in Git.
- **Auth:** Token in header; never log tokens client/server.
- **PII:** Store only required user data (Django user + meals); no third-party telemetry.
- **CORS/CSRF:** Standard DRF settings; token-based auth for API calls.

---

## 12) Performance

- **Queries:** `select_related('food__nutrients')` for list/summary; indexed FKs.
- **Pagination:** DRF default; reasonable page sizes.
- **Latency targets:** P50 ≤300ms, P95 ≤800ms with 100 entries/day.

---

## 13) Analytics (lightweight)

- Client-side: optional local counters (e.g., meals logged per day).
- Server-side: request logs, error rates (development only; no sensitive data).

---

## 14) Release Plan & Milestones

1. **MVP Complete** (✅): Barcode import, meals CRUD, TZ-aware list/summary, token screen, web runbook.
2. **Daily Goals & Progress (✅)**: Local goals; progress bars on summary.
3. **Date Picker (✅)**: Drives both cards; Today/Yesterday shortcuts.
4. **Polish (⏳)**: UI consistency, error messages, empty states, small perf wins.
5. **Android (▶)**: Cleartext dev config; barcode scanner; test on emulator/device.
6. **Profile Sync (Later)**: Server profile with goals; multi-device.

---

## 15) Risks & Mitigations

- **OFF variability:** Missing fields → robust coercion & defaults; show “Unknown” where needed.
- **Timezone gotchas:** Single helper for list/summary; tests for DST boundaries.
- **Token issues:** Clear UX for 401; persistent token; one dev port (e.g., 5173).
- **Data accuracy:** Summary/list invariant tests; unit checks on nutrient math.

---

## 16) QA / Test Plan (high level)

- **Backend (cURL):**

  - Meals POST/GET/PATCH/DELETE; Summary totals equal list aggregates.
  - Date window sanity: today, yesterday, future empty.

- **Frontend (manual):**

  - Token save/clear returns to barcode and refreshes.
  - Import known barcode; Add to Meal; Summary updates.
  - Edit/Delete meals; Summary updates.
  - Date picker changes both cards; goals progress recalculates.
  - Error states: 401 (missing token), 404 (unknown barcode), 5xx (OFF proxy).

---

## 17) Open Questions

- Do we want per-meal **serving units** (e.g., slices) now or stick to grams?
- How soon should we move **goals** to server profile for multi-device sync?
- Should we add **offline caching** for recently imported foods?

---

## 18) Out of Scope (for now)

- Social/sharing, complex micronutrients, paid plans, wearable integrations, reminders/notifications.

---

## 19) Appendices

### API Examples: Requests

- **Create meal (PowerShell example)**

```powershell
$FOOD_ID = 11
$NOW = Get-Date -Format "s"
$payload = @{ food=$FOOD_ID; quantity=150; meal_time=$NOW; notes="snack" } | ConvertTo-Json -Compress
curl.exe -i -X POST -H "Authorization: Token $env:TOKEN" -H "Content-Type: application/json" --data $payload "http://127.0.0.1:8000/api/meals/"
```

- **List meals for a day**

```powershell
$DATE = (Get-Date).ToString('yyyy-MM-dd')
curl.exe -H "Authorization: Token $env:TOKEN" "http://127.0.0.1:8000/api/meals/?date=$DATE&tz=America/Los_Angeles"
```

- **Daily summary**

```powershell
curl.exe -H "Authorization: Token $env:TOKEN" "http://127.0.0.1:8000/api/meals/summary/?date=$DATE&tz=America/Los_Angeles"
```

---

**End of PRD**
