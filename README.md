# Relay · Big reach. Personal touch.

A full-stack, consent-first WhatsApp marketing workspace built with **Flutter** and **FastAPI + SQLite**. The running browser preview is the actual Flutter app, not a separate React mockup. Android and iOS source projects are included.

## What you can do

- **Authentication:** register a private workspace, sign in, keep a persistent session, edit your profile, and sign out. Passwords use salted PBKDF2; only session-token hashes are stored on the server.
- **Dashboard:** live database-backed contact totals, campaign counts, delivery/read analytics, activity, and recent/upcoming campaigns. Seven-, fourteen-, and thirty-day ranges are functional.
- **Contacts:** create, search, filter, paginate, edit, delete, select, and bulk-delete contacts. Record explicit opt-in, its source, or an unsubscribe.
- **Group imports:** create an audience group, upload a consented CSV, preview/validate rows, skip duplicates, and save the list together. Existing consent is never silently overwritten by an import.
- **Bulk contact saving:** export a group or selection as a single `.vcf` file. On Android/iOS, request address-book permission and insert contacts directly, skipping matching phone numbers and fictional demo records.
- **Campaigns:** create drafts, choose an audience/template, personalize first names, schedule, edit unsent campaigns, duplicate, cancel, delete, and review individual delivery receipts.
- **Templates:** complete local CRUD, categories, variables, message previews, and official Meta template sync.
- **Analytics:** interactive series toggles, audience segmentation, campaign rankings, date filters, and CSV reports.
- **Settings:** persistent workspace details, activity preferences, encrypted WhatsApp Business credentials, and data exports.
- **UX:** desktop sidebar, mobile drawer and bottom navigation, responsive cards/tables, empty/loading/error states, optimistic deletions with rollback, accessible semantics, and keyboard search (`Ctrl/Cmd + K`).

## Important WhatsApp boundary

**Relay does not open a personal WhatsApp account, scrape existing WhatsApp groups, extract private group-member phone numbers, or bypass WhatsApp protections.** The group picker selects groups stored in your Relay workspace. Import a contact list you are authorized to possess and use.

Live outbound campaigns use the **official WhatsApp Business Cloud API** and **Meta-approved text-body templates**. They exclude pending, unsubscribed, and fictional demo contacts. An opt-in source is required. Marketing templates should include a clear opt-out instruction. Signed inbound webhooks recognize `STOP`, `UNSUBSCRIBE`, `CANCEL`, and `OPT OUT`.

### Demo vs. live

| Demo mode | Live mode |
|---|---|
| Available immediately | Requires your own registered workspace |
| Fictional seeded contacts | Your authorized, explicitly opted-in contacts |
| Simulated delivery/read receipts | Official Meta submission + signed status webhooks |
| Any local draft can be tested | Only verified, synced, approved text-body templates |
| No messages leave the application | Explicit live confirmation; Meta fees/policies apply |

The shared demo includes **2,486 synthetic contacts, 6 groups, 10 campaigns, 6 templates, and 7,558 simulated delivery records**. New accounts start empty and are owner-scoped. Mutations in the shared demo are persistent. Demo credentials: `alex@relay.demo` / `Demo@1234`.

## Run the ready-built app

The `web_release/` directory contains a ready-to-serve Flutter web build. **You do not need Flutter installed to run this preview.**

```bash
cd relay
python -m pip install -r backend/requirements.txt
./scripts/start.sh
```

Open `http://localhost:8000`. API documentation: `http://localhost:8000/docs`. The server binds to `0.0.0.0` and accepts the preview host. Browser requests use the same origin, never hardcoded localhost URLs.

Persistent data defaults to `backend/data/relay.sqlite3`. Set `RELAY_DATA_DIR` to a persistent volume in deployment. The schema and demo are created on first start. Deleting the database resets the demonstration (stop the server first).

### Docker

```bash
docker build -t relay .
docker run --rm -p 8000:8000 --env-file .env -v relay-data:/data relay
```

Copy `.env.example` to `.env` first. The image runs as a non-root user. Do not enable the publicly writable demo in a production installation.

## Flutter development

**Validated toolchain: Flutter 3.24.5 / Dart 3.5.4.** This version supports the HTML renderer used by the lightweight, self-hosted browser preview. Newer Flutter versions that remove that renderer require updating the web build script/bootstrap to CanvasKit or skwasm and retaining their engine assets.

If needed, install the pinned SDK from source:

```bash
git clone --branch 3.24.5 --depth 1 https://github.com/flutter/flutter.git flutter-sdk
export PATH="$PWD/flutter-sdk/bin:$PATH"
flutter --version
```

```bash
cd mobile
flutter pub get
flutter analyze
flutter test
cd ..
./scripts/build_web.sh
./scripts/start.sh
```

You can set `FLUTTER_BIN=/absolute/path/to/flutter` when running the build script. The build is stored in `web_release/`, without CDN dependencies, service-worker caching, or unused CanvasKit artifacts.

### Android / iOS

Native builds must point to a reachable backend:

```bash
cd mobile
flutter run --dart-define=API_BASE_URL=https://your-relay-api.example
flutter build apk --release --dart-define=API_BASE_URL=https://your-relay-api.example
# macOS + Xcode + Apple signing required:
flutter build ios --release --dart-define=API_BASE_URL=https://your-relay-api.example
```

Use **JDK 17** for the generated Android Gradle configuration and install an Android SDK. Configure release signing before distributing an APK. Use HTTPS for native API calls. The supplied native manifests include internet and contacts permissions plus a human-readable iOS contacts usage description. Native tokens use `flutter_secure_storage`; browser demo sessions use local storage.

**Platform verification:** Flutter static analysis, widget tests, the compiled Flutter web app, and API integration tests are exercised here. APK/IPA packaging and physical-device contact permission/insertion must be validated on your Android/iOS toolchains; no signed native binary is included.

## Connect real WhatsApp Business

1. Register your own workspace (sign out of the demo).
2. Set up a verified Meta WhatsApp Business account and business phone.
3. In **Settings → Connect WhatsApp**, enter the Phone Number ID, WABA ID, and a system-user access token with the required messaging/management permissions.
4. Relay verifies the phone ID with Meta and encrypts the token server-side using Fernet. It is never returned to the frontend.
5. Create and approve a **text-body-only template with numbered variables** in WhatsApp Manager. Use **Templates → Sync from WhatsApp**.
6. Configure the public HTTPS webhook URL shown in Settings and set `WHATSAPP_VERIFY_TOKEN` and `WHATSAPP_APP_SECRET` in your server environment.
7. Import only contacts with permission, record its source, select a synced approved template, switch to Live mode, and explicitly confirm sending/scheduling.

Variable `{{1}}` is the contact's first name. Campaign inputs supply any additional body variables, up to five total. Media headers, buttons, carousels, and named-variable templates are intentionally skipped by the current sync implementation. Select `META_API_VERSION` for your supported Graph API version.

## CSV format

```csv
first_name,last_name,phone,email,consent_status
Amara,Okafor,+12025550101,amara@demo.example,opted_in
Sarah,Johnson,+12025550102,sarah@demo.example,pending
```

These example numbers are reserved fictional numbers, marked as demo records by the server. Replace them with real contacts you are authorized to use. Phone numbers need a country code (`+234...`, for example). Imports support UTF-8 CSVs, a maximum of 2 MB and 5,000 rows. Explicitly confirm permission and its source; otherwise contacts remain pending even if the CSV says `opted_in`.

## Tests

```bash
python -m unittest backend.test_api -v
cd mobile && flutter analyze && flutter test
# With the server running, from the project root:
npm install
npx playwright install --with-deps chromium
npm run test:e2e
```

The Python suite uses a disposable database and checks authentication, owner isolation, consent validation, contact/group/template/campaign CRUD, CSV imports, exports, duplicate protection, opt-out exclusion, simulated delivery, idempotent sending, and live-mode guardrails. Flutter widget tests cover empty/populated states at 320, 390, 1100, and 1440 pixel widths, long workspace names, and short-screen mobile navigation. The checked build passes 26 widget tests, 9 API tests, and 32 browser end-to-end checks. Live provider requests and physical-device address-book writes still require your own integration/device verification.

## Project map

```
backend/
  app.py             REST API, authentication, scheduler, exports, webhooks, web hosting
  database.py        SQLite schema, password hashing, deterministic demo seed
  provider.py        Official Cloud API client and encrypted credential storage
  test_api.py        Disposable-database API integration tests
mobile/
  lib/core/          HTTP/session client, state controller, contact saving, downloads
  lib/ui/            Shell, auth, pages, dialogs, visualizations, theme
  android/           Native Android project and permissions
  ios/               Native iOS project and permissions
  web/               Self-hosted Flutter bootstrap, loading screen, PWA metadata
web_release/         Ready-built Flutter web application
scripts/             Build and run scripts
```

## Before production

This is a complete functional development starter, **not a claim of production certification**. See `docs/PRODUCTION.md` for hardening, backups, consent governance, native signing, operational limits, and deployment considerations.
