# Kobo-Compatible Offline Data Collection Platform Architecture

## 1. Objectives

Build a production-grade, Kobo Collect-equivalent platform with:
- Direct Kobo credential authentication.
- Dynamic XForm-driven data capture.
- Fully offline-capable mobile operation.
- ODK/OpenRosa-compliant instance XML + media submission.
- Optional stateless ASP.NET Core proxy.

## 2. High-Level Architecture

```text
+--------------------------+         +-------------------------+
| React Native Mobile App  | HTTPS   | KoboToolbox Server      |
|--------------------------|<------->|-------------------------|
| - Kobo auth client       |         | - v2 REST API           |
| - XForm fetch/cache      |         | - ODK/OpenRosa endpoints|
| - Dynamic form renderer  |         | - token/auth endpoints  |
| - Offline encrypted DB   |         +-------------------------+
| - XML instance builder   |
| - Multipart submitter    |         +-------------------------+
| - Sync engine            | HTTPS   | Optional ASP.NET Core   |
+-------------+------------+<------->| Proxy API (Stateless)   |
              |                      | - transparent auth pass |
              |                      | - form passthrough      |
              |                      | - submission passthrough|
              |                      | - sync telemetry logs   |
              |                      +------------+------------+
              |                                   |
              |                            SQL Server (optional)
              |                            - forms cache metadata
              |                            - submissions log
              |                            - media map
              |                            - sync audit
```

## 3. Core Design Decisions

1. **XML is source of truth**: Preserve original XForm XML exactly as downloaded.
2. **No JSON submission to Kobo**: Submission payload is ODK instance XML + media multipart.
3. **Offline-first**: Form fill, draft save, finalization, and queueing all work offline.
4. **Idempotent sync**: Prevent duplicates via deterministic `instanceID` and dedupe checks.
5. **Secure by default**: Token/keychain storage, SQLCipher encryption, TLS pinning option.

## 4. Mobile Modules (React Native + TypeScript)

### 4.1 Suggested Technology
- React Native 0.74+ with TypeScript strict mode.
- State: Zustand or Redux Toolkit.
- Local DB: SQLite + SQLCipher (via `react-native-quick-sqlite`/native binding) or WatermelonDB with encrypted adapter.
- Secure secrets: `react-native-keychain` (iOS Keychain / Android Keystore-backed encrypted storage).
- Files: `react-native-fs`.
- Connectivity: `@react-native-community/netinfo`.
- Background tasks:
  - Android: Headless JS + WorkManager bridge.
  - iOS: BGTaskScheduler.
- XML parser/generator:
  - Parse XForm: `fast-xml-parser` with preserving namespaces.
  - Build submission XML: custom deterministic XML writer (not JSON serializer-based shortcut).

### 4.2 Mobile Bounded Contexts
- **Auth Context**: Kobo server URL, credential login, token lifecycle.
- **Form Catalog Context**: fetch/decrypt/store form manifests + XForm XML.
- **Runtime Rendering Context**: parse XForm into render model and evaluate logic.
- **Draft/Instance Context**: draft answers, finalized instances, attachments.
- **Sync Context**: queued submissions, retries, backoff, final status transitions.

## 5. Kobo Integration Endpoints

> Exact endpoint path can vary by Kobo deployment; app supports configurable base URL and endpoint discovery by capability probes.

- Token/Auth (Kobo API v2-compatible deployment).
- Form list endpoint (asset/form metadata).
- XForm download endpoint (raw XML, versioned).
- ODK/OpenRosa submission endpoint (`/submission` or deployment-specific equivalent).

## 6. End-to-End Flows

### 6.1 Login
1. Enumerator enters `serverUrl`, username, password.
2. App calls Kobo auth endpoint over HTTPS.
3. Access token + refresh token (or API token) securely stored.
4. Server capabilities cached (OpenRosa URL, API version).

### 6.2 Form Sync
1. Pull form manifest (formId, version, hash, title, download URL).
2. Download XForm XML for each form/version.
3. Store original XML blob + normalized parse cache.
4. Download linked media (choices images, audio prompts) and checksum.

### 6.3 Fill Form Offline
1. Open form from local catalog.
2. Renderer constructs dynamic pages from XML model.
3. Constraint/calc/relevance executed on answer updates.
4. Save draft transactionally on every step and explicit save.

### 6.4 Finalize + Queue Submission
1. Validate required fields and constraints.
2. Generate instance XML with exact node hierarchy.
3. Freeze draft to immutable completed submission record.
4. Set state `Pending Upload`.

### 6.5 Background Upload
1. Sync worker picks oldest pending submission.
2. Create multipart payload: XML file part first + media parts.
3. Attach auth header/token/cookie per Kobo requirement.
4. On success: mark `Synced` and store remote receipt.
5. On failure: classify transient/permanent and retry with backoff.

## 7. State Machine

```text
Draft -> Completed -> Pending Upload -> Synced
   \           \            \-> Failed
    \-> Failed  \-> Failed
```

Transition rules:
- `Draft -> Completed`: user finalizes successfully.
- `Completed -> Pending Upload`: submission package generated.
- `Pending Upload -> Synced`: 2xx from Kobo + parse success response.
- `Pending Upload -> Failed`: non-retryable 4xx (invalid XML, auth denied).
- `Failed -> Pending Upload`: user retry/manual edit or auto-retry for transient class.

## 8. Duplicate Prevention Strategy

- Use deterministic `instanceID` UUID generated at first draft creation and never replaced.
- Include `meta/instanceID` in XML exactly once.
- Maintain unique local DB constraint on `(server_url, form_id, instance_id)`.
- For retries, resend same XML + same attachment names.

## 9. Security Controls

- TLS 1.2+ only.
- Optional certificate pinning (recommended for enterprise-managed deployments).
- Tokens in OS secure enclave/keystore only.
- Database encryption key derived from secure random + hardware-backed storage.
- PII file attachments encrypted at rest before upload window.
- Automatic logout + key wipe on device compromise signal / MDM trigger.

## 10. Performance & Scalability

- Incremental form sync by ETag/hash/version.
- Stream multipart uploads to avoid memory spikes.
- Background jobs constrained by battery/network policy.
- Parser cache for large XForms to avoid repeated full parse.

## 11. Observability

- Local sync logs with reason codes.
- Optional proxy emits structured logs (correlation-id per submission).
- Metrics: sync success rate, retry depth, median upload latency, auth failure rates.

