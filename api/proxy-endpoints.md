# ASP.NET Core 8 Proxy API Specification (Optional Layer)

## 1. Design Principles
- Stateless request handling.
- Transparent forwarding to Kobo APIs and OpenRosa endpoints.
- No mutation of XML payload submitted by mobile clients.
- Correlation ID propagation for observability.

## 2. Authentication Model
- Mobile app can call Kobo directly OR proxy.
- If proxy is used, it forwards credentials/token exchange to Kobo.
- Proxy stores no raw passwords.

## 3. Endpoints

### POST `/api/v1/auth/login`
Authenticate against Kobo using server URL + username/password.

**Request**
```json
{
  "serverUrl": "https://kf.example.org",
  "username": "enumerator1",
  "password": "***"
}
```

**Response 200**
```json
{
  "accessToken": "...",
  "refreshToken": "...",
  "tokenType": "Bearer",
  "expiresIn": 3600,
  "koboUser": {
    "username": "enumerator1",
    "displayName": "Enumerator One"
  },
  "capabilities": {
    "apiBase": "https://kf.example.org/api/v2",
    "openRosaSubmissionUrl": "https://kf.example.org/submission"
  }
}
```

### GET `/api/v1/forms`
Fetch form manifest from Kobo and optionally enrich with local sync metadata.

Query: `serverUrl`, `includeArchived`, `updatedAfter`.

### GET `/api/v1/forms/{formId}/versions/{versionHash}/xform`
Returns the **original** XForm XML stream (`application/xml`).

### POST `/api/v1/submissions`
Upload finalized ODK instance as multipart without transformation.

**Content-Type**: `multipart/form-data`

Parts:
1. `xml_submission_file` -> XML instance file (required)
2. media file parts (optional, repeated)

Headers:
- `Authorization: Bearer ...` (Kobo token)
- `X-OpenRosa-Version: 1.0`
- `Date` (RFC1123)

Response maps Kobo response with minimal wrapper:
```json
{
  "status": "accepted",
  "httpStatus": 201,
  "koboResponse": "<OpenRosaResponse ...>",
  "submissionKey": "uuid:..."
}
```

### GET `/api/v1/submissions/{instanceId}/status`
Return local proxy-tracked state for diagnostics.

## 4. ASP.NET Core Implementation Notes

- `HttpClientFactory` typed clients:
  - `KoboApiClient`
  - `KoboOpenRosaClient`
- Streaming relay:
  - Use `MultipartReader` for incoming parts.
  - Rebuild `MultipartFormDataContent` preserving file names/content types/order.
- Security:
  - Reject non-HTTPS server URLs unless explicitly allowlisted for dev.
  - Request body size limit configurable.
- Idempotency:
  - Optional `Idempotency-Key` header stored in distributed cache (TTL 24h).

## 5. Error Mapping

| Kobo HTTP | Proxy code | Retry? | App transition |
|---|---:|---|---|
| 2xx | 200/201 | No | `Synced` |
| 400 | 422 | No | `Failed` |
| 401/403 | 401 | After re-auth | `Failed` or requeue |
| 404 form | 409 | No | `Failed` |
| 408/429/5xx | 503 | Yes | `Pending Upload` with backoff |

