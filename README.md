# ACVAR3 - Kobo-Compatible Mobile Data Collection Platform

This repository now contains production-grade architecture and technical specifications to implement a Kobo Collect-equivalent mobile platform with optional ASP.NET Core proxy.

## Included Deliverables

1. **System architecture**
   - `docs/architecture.md`
2. **SQL Server database schema**
   - `sql/schema.sql`
3. **ASP.NET Core API endpoint specifications**
   - `api/proxy-endpoints.md`
4. **ODK XML instance generation specification**
   - `specs/xml-instance-generation.md`
5. **Offline sync algorithm + UX triggers + renderer design**
   - `docs/mobile/form-renderer-and-sync.md`
6. **EF Core data model guidance**
   - `docs/backend/ef-core-model.md`

## Implementation Roadmap (Execution in One Go)

### Phase 1 - Foundation (Week 1-2)
- Bootstrap RN TypeScript app and ASP.NET Core 8 API.
- Implement secure Kobo login and capability discovery.
- Create encrypted local DB schema and key management.

### Phase 2 - Form Runtime (Week 3-5)
- Build XForm parser and normalized runtime model.
- Implement question renderer, constraints, relevance, calculations.
- Add repeat group runtime and media capture pipeline.

### Phase 3 - Submission Pipeline (Week 6-7)
- Implement deterministic instance XML generator.
- Add multipart ODK submitter and receipt parser.
- Integrate sync state machine with retry/backoff.

### Phase 4 - Hardening (Week 8-9)
- Add instrumentation, sync diagnostics, and edge-case handling.
- Security hardening (TLS pinning, token lifecycle, encrypted file handling).
- End-to-end tests against Kobo sandbox.

### Phase 5 - Release (Week 10)
- Pilot rollout, telemetry review, bugfixes.
- Publish operational runbook and SLO dashboards.

## Non-Negotiable Compliance Rules
- Preserve and store original XForm XML.
- Submit only ODK instance XML + media multipart to Kobo endpoints.
- Support offline-first workflows with eventual sync.
- Never hardcode forms.

