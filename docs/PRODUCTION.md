# Production checklist

## Privacy and permission

- Never scrape existing personal-account WhatsApp groups or use unofficial WhatsApp Web automation.
- Keep auditable records of marketing opt-in (source, timestamp, wording, withdrawal). An entered source is a record, not independent proof of consent.
- Determine the legal basis for collecting/exporting/saving contacts and comply with applicable privacy rules, including Nigerian requirements where relevant. Obtain legal review for your actual markets.
- Respect unsubscribes immediately; suppress delivery at queue creation **and again before each send**.
- Minimize retained PII and establish deletion/retention policies for contact data and message phone snapshots.
- Never upload private contact lists to the shared demo. Register an isolated workspace instead.

## Authentication and secrets

- Set `RELAY_DEMO_ENABLED=0` in production. The browser falls back to sign-in instead of auto-entering the demo.
- Set a long random `RELAY_SECRET_KEY`, keep it outside source control, and store it in a secrets manager. Preserve it when restarting; changing it makes previously encrypted provider tokens unreadable.
- The generated fallback `backend/data/.secret` is for development only. Back up and protect the key separately from the database.
- HTTPS is mandatory for deployment. Do not expose plaintext access tokens, passwords, or bearer tokens in logs.
- Native sessions use secure platform storage. Replace browser local-storage bearer sessions with a hardened HttpOnly/Secure/SameSite cookie or a reviewed BFF flow before public production exposure.
- Add email verification, password recovery, MFA if required, account lifecycle controls, trusted-proxy rate limiting, and centralized audit logs.
- The included per-IP authentication limiter is in-memory and intended for a single-process starter. Use shared enforcement behind a trusted reverse proxy for production.

## Sending and operations

- Connect an official WhatsApp Business Cloud API account, verify account eligibility, keep tokens rotated, and follow provider policies, limits, template rules, and messaging charges.
- Configure verified status/opt-out webhooks. Without them, live submissions remain `sent` and delivery/read analytics cannot be asserted.
- This implementation supports approved text-body-only templates with consecutive numbered variables, not media headers, template buttons, carousels, or named parameters.
- Run a **single API worker** with the included SQLite scheduler. Multiple workers would require a properly coordinated durable queue and distributed job leasing.
- For scale, migrate to PostgreSQL + a durable queue (for example, a worker service). Add account-specific throughput limits, unsubscribe races mitigation, back-pressure, exponential backoff, provider-error classification, and observability.
- The starter submits messages at a conservative fixed cadence. It does not attempt unlimited throughput or bypass provider protections.
- Queued sends survive restart. An in-flight record at restart is marked failed/unknown rather than blindly re-sent, preventing accidental duplicate messages. Review uncertain provider submissions manually.
- Completed live campaigns mean processing/submission finished; individual message receipts determine delivery/read/failure counts.
- Consent changes after queuing are checked again by the sender. Keep in mind an already-submitted message cannot be recalled by canceling a campaign.

## Data, deployment, and monitoring

- Mount a persistent volume at `RELAY_DATA_DIR`. Restrict directory permissions. SQLite uses foreign keys and WAL mode.
- Take consistent backups using SQLite's backup API or stop/checkpoint the database before filesystem copies. Never copy only the main database file during active WAL writes.
- Separate encryption-key backups from database backups. Test restoration.
- Restrict CORS with explicit `RELAY_ALLOWED_ORIGINS` if deploying web and API separately. The bundled preview uses one host and requires no CORS exception.
- Place the API behind a TLS reverse proxy, add request/body limits, security headers suitable for Flutter, health monitoring, structured redacted logs, and alerting.
- Pin/review dependencies and perform a security assessment before handling real users' data.
- Add schema migrations for future releases instead of changing a deployed schema through seed logic.
- Keep API integration credentials and sample test sessions out of downloadable source archives.

## Mobile release

- Configure a reachable HTTPS `API_BASE_URL`; browser code must not point to sandbox localhost.
- Test contact permission denial/revocation, duplicate handling, large-list cancellation, partial contact-write errors, and background/resume scenarios on physical Android/iOS devices.
- Address-book writes are sequential and not transactionally reversible across platforms. Preview the list and require explicit user confirmation.
- Only API contacts—not WhatsApp's private internal database—are saved. Fictional demo records are excluded from direct native saves.
- Create signed Android releases and configure Apple signing/provisioning. Review platform privacy disclosures and store policies for contact access and marketing software.
- The included Flutter 3.24.5 web toolchain is pinned for the HTML preview. Upgrade the native/web toolchains deliberately, update deprecated plugins/renderers, and rerun tests before release.

## Deliberately not included

- Group-member scraping, unsolicited messaging, rate-limit evasion, or unofficial WhatsApp personal-account login.
- A payment system, billing subscriptions, email transport, media campaigns, multi-admin RBAC, shared inbox/chat UI, or native background sending service.
- The dashboard is operational but is not a full attribution/ROI analytics system. Current charts group delivery records by UTC date; schedule pickers and display timestamps use device local time. The saved workspace timezone is a preference for further localization work.
