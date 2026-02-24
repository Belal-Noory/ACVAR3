# Mobile UI Component Architecture, Form Renderer, and Offline Sync

## 1. UI Component Architecture

## 1.1 Screen Map
- `ServerConfigScreen` (server URL + environment profile)
- `LoginScreen` (Kobo credentials)
- `FormListScreen` (downloaded forms, versions, sync age)
- `FormEntryScreen` (dynamic renderer)
- `DraftsScreen` (Draft/Completed/Pending/Failed)
- `SyncCenterScreen` (queue, retry action, logs)
- `SubmissionDetailScreen` (payload/attachment diagnostics)

## 1.2 Core Components
- `FormRenderer`: orchestrates sections/pages from parsed XForm.
- `QuestionFactory`: maps XForm question type to UI control.
- `ConstraintBanner`: inline validation and expression failure details.
- `RepeatGroupCard`: add/remove/reorder repeat instances.
- `MediaCaptureField`: camera/audio/file picker and file lifecycle handling.
- `ProgressFooter`: required completion stats + save/finalize actions.
- `NetworkBadge`: global online/offline indicator.

## 1.3 Form Engine Layers
- `XFormParserService`
- `ExpressionEvaluatorService` (XPath subset + functions)
- `RelevanceResolver`
- `ConstraintValidator`
- `CalculationEngine`
- `InstanceAssembler`

## 2. Dynamic Rendering Support Requirements

### 2.1 Supported question families
- text, integer, decimal, select_one, select_multiple, date, time, datetime, geopoint
- begin_group/end_group
- begin_repeat/end_repeat (nested support)
- image/audio/file
- calculate + hidden metadata fields

### 2.2 Expression lifecycle
On each answer update:
1. Update answer store.
2. Recompute calculated fields dependency graph.
3. Recompute relevance visibility.
4. Revalidate impacted constraints.
5. Persist draft delta.

## 3. Offline Sync Algorithm

## 3.1 Queue Model
- Local queue table keyed by `submissionId`.
- Enforced ordered processing by `createdAt` then priority.

## 3.2 Retry with Exponential Backoff
- Base delay: 30s.
- Backoff: `next = base * 2^retryCount` capped at 1h.
- Random jitter: ±15%.
- Max automatic retries before manual review: 10.

## 3.3 Worker Pseudocode

```text
while app_active_or_background_window:
  if !network_online: sleep(15s); continue

  item = queue.nextDue(now)
  if none: sleep(10s); continue

  mark(item, Uploading)
  result = submitMultipart(item.frozenXml, item.media)

  if result.success:
     mark(item, Synced, syncedAt=now, receipt=result.receipt)
  else if result.transient:
     item.retryCount++
     item.nextRetryAt = expBackoff(item.retryCount)
     mark(item, PendingUpload, lastError=result.error)
  else:
     mark(item, Failed, lastError=result.error)
```

## 3.4 UX Triggers
- Auto sync trigger when connectivity changes offline -> online.
- Manual “Sync now” button in Sync Center.
- Passive retry in background windows.
- Clear per-submission error reason and one-tap retry.

## 4. Draft and Finalization UX
- Autosave every meaningful change.
- Explicit `Save Draft` and `Finalize` actions.
- On finalize, show summary of required completeness and media attachment count.
- Finalized submissions immutable; edits require “Create corrected copy” pattern.

## 5. Network State UX
- Persistent top badge:
  - Green: Online
  - Amber: Limited (high latency)
  - Gray: Offline
- Queue icon counter for pending uploads.
- Toasts for transitions: synced, failed, retry scheduled.

