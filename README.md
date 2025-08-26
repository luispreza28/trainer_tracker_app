# Trainer Tracker – Dev Quickstart (Windows + Android)

> This is a practical, copy‑pasteable quickstart for running the **Django backend** locally and the **Flutter app** on a **physical Android phone** using a **Cloudflare Tunnel** URL for API traffic.

---

## 0) Prereqs

- **Flutter** SDK installed and on PATH (`flutter --version`).
- **Android Studio** with SDK + platform tools; accept licenses.
- **Android NDK** **27.0.12077973** (plugins like `path_provider_android` require 27).
- **Python 3.12+** for Django backend.
- (Optional) **Docker Desktop** if you want to run the backend in containers.

Check basics:
```powershell
flutter doctor -v
python --version
```

---

## 1) Backend (Django) – Local dev server

From repo root:

```powershell
# 1) Create & activate venv (if not already)
python -m venv venv
.\venv\Scripts\Activate.ps1

# 2) Install deps
pip install -r backend\requirements.txt

# 3) Migrate DB
python backend\manage.py migrate

# 4) Runserver (bind to all interfaces for phone access)
python backend\manage.py runserver 0.0.0.0:8000
```

### Required Django settings (already configured)
- `ALLOWED_HOSTS = ['*', 'localhost', '127.0.0.1', '10.0.2.2', '.trycloudflare.com']`
- `CSRF_TRUSTED_ORIGINS = ['https://*.trycloudflare.com']`
- `CORS_ALLOWED_ORIGINS = ['http://localhost:3000', 'http://localhost:8080', 'https://*.trycloudflare.com']`
- `USE_X_FORWARDED_HOST = True`
- `SECURE_PROXY_SSL_HEADER = ('HTTP_X_FORWARDED_PROTO','https')`

> 404 at `/` is normal; your API is under `/api/...`.

---

## 2) Cloudflare Tunnel (for the phone to reach your PC)

Open a **new** terminal and run:

```powershell
cloudflared tunnel --url http://localhost:8000
```

You’ll see a line like:

```
Your quick Tunnel has been created! Visit it at:
https://<random-name>.trycloudflare.com
```

Copy this full `https://...trycloudflare.com` **origin** URL. It must be reachable over the internet.

> If Cloudflare shows warnings about certs, that’s fine for quick tunnels.

---

## 3) Flutter – Point the app at your Cloudflare URL & run

From repo root:

```powershell
cd frontend

# Optional maintenance
flutter clean
flutter pub get

# Make sure Android NDK matches what plugins expect (27.0.12077973)
# In android/app/build.gradle.kts ensure:
# android { ndkVersion = "27.0.12077973" }

# IMPORTANT: pass the Cloudflare URL (NO /api suffix; the app appends /api)
flutter run -d <YOUR_DEVICE_ID> `
  --dart-define=API_BASE_URL="https://<random-name>.trycloudflare.com/"
```

Find your device id via `flutter devices` (e.g., `R5CXXXXXX`).

> Each time you restart `cloudflared`, the domain changes; rerun Flutter with the **new** `API_BASE_URL`.

---

## 4) Optional: Backend via Docker

Replace step 1 with:

```powershell
# Build & run (exposes http://localhost:8000)
docker compose up --build

# Stop later
docker compose down
```

Then still do **Cloudflared** (step 2) and **Flutter** (step 3).

---

## 5) Troubleshooting

### A) Base URL shows `null` in logs
- We log at startup:
  - `MAIN API_BASE_URL="<value>"` (from `main.dart`)
  - `ApiClientCTOR base = <value>` (from `ApiClient`)
- If it’s `null`:
  - Ensure you passed `--dart-define=API_BASE_URL=...` (no `/api` suffix; keep trailing slash OK).
  - Search for hard-coded URLs (should be none) and ensure all API paths go through the `ApiClient` helper.

### B) CORS/CSRF errors
- Ensure settings (above) include `.trycloudflare.com` wildcards.
- Restart Django after settings changes.
- If using Docker, rebuild (`docker compose up --build`).

### C) ADB reverse (optional alternative to Cloudflare)
If `adb` is on PATH and the phone is USB‑connected with developer mode:
```powershell
adb reverse tcp:8000 tcp:8000
flutter run -d <device> --dart-define=API_BASE_URL="http://127.0.0.1:8000/"
```
> If `adb` isn’t recognized, stick with Cloudflare.

### D) Android NDK mismatch (seen during builds)
If Flutter warns:
```
path_provider_android requires Android NDK 27.0.12077973
```
Add in `android/app/build.gradle.kts`:
```kotlin
android {
    ndkVersion = "27.0.12077973"
}
```

### E) Gradle hiccups
```powershell
cd frontend\android
.\gradlew --stop
Remove-Item -Recurse -Force .\.gradle -ErrorAction SilentlyContinue
cd ..
flutter clean
flutter pub get
```

### F) INTERNET permission (Android)
Ensure `android/app/src/main/AndroidManifest.xml` has:
```xml
<uses-permission android:name="android.permission.INTERNET" />
```

---

## 6) Day‑to‑day Flow

1) Start Django (or Docker) → `localhost:8000`
2) Start Cloudflared → copy the `https://...trycloudflare.com`
3) Run Flutter with `--dart-define=API_BASE_URL="<that-url>/"`
4) If tunnel changes, rerun Flutter with the new URL.

---

## 7) Pre‑push sanity (quick)

- ✅ App builds & runs on device with `--dart-define=API_BASE_URL=...`
- ✅ `ApiClient` logs show a **non-null** base and resolves URLs via its `_u()` helper.
- ✅ No hard-coded `http://` or `https://` left except comments/tests.
- ✅ Backend CORS/CSRF/ALLOWED_HOSTS include `*.trycloudflare.com`
- ✅ `INTERNET` permission present
- ✅ Android NDK pinned to `27.0.12077973`
- ✅ `.gitignore` covers secrets, envs, and Android build junk
- ✅ Commit & push when green
