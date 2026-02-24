# ODK/Kobo XML Instance Generation Specification

## 1. Inputs
- Original XForm XML (exact version used during fill).
- User answer map keyed by bind path.
- Repeat group records with preserved order.
- Media attachment registry (question path -> file metadata).

## 2. Output
- UTF-8 XML file with same root element, namespace, and node structure expected by Kobo.
- Includes `meta/instanceID` in OpenRosa format (e.g., `uuid:xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`).

## 3. Rules

1. Parse model section (`<model><instance>`) from XForm and treat it as template tree.
2. Keep original element names and namespaces unchanged.
3. Emit nodes in template order.
4. For unanswered optional fields, emit empty node unless XForm explicitly omits via relevance logic at instance template level.
5. For repeats:
   - Duplicate repeat element for each collected record in order entered.
   - Apply nested repeat recursion similarly.
6. For select_multiple:
   - Store value as space-separated choice names.
7. For geopoint/date/time/datetime:
   - Serialize in ODK canonical format.
8. For media questions:
   - XML node value must be attached file name, exactly matching multipart part filename.
9. Escape XML entities; never CDATA-wrap unless source model requires it.

## 4. File Naming
- XML file name: `instance.xml` (or `<instanceId>.xml` if deployment prefers).
- Media names deterministic and unique:
  - Keep captured original file names if valid.
  - On collision append `_<n>` before extension.

## 5. Multipart Assembly
- Part 1 (required):
  - name: `xml_submission_file`
  - filename: XML file name
  - content-type: `text/xml`
- Remaining parts (0..n):
  - name: attachment filename (ODK-compatible behavior)
  - filename/content-type preserved from media registry
  - order by `sortOrder` captured during generation

## 6. Validation Before Queueing
- XML schema sanity checks (well-formed, root exists).
- Required fields present (based on resolved relevance/required expressions).
- Attachment references in XML all present in media table.
- Hash generated for XML and each file for audit/retry integrity.

## 7. Determinism Guarantees
- Same draft state must yield byte-identical XML (except allowed timestamp nodes if configured).
- Re-uploads for retry use frozen generated XML/media files from finalized snapshot; never regenerate from mutable draft.

