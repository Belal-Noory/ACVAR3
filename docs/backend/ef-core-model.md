# EF Core 8 Model Mapping (SQL Server)

## DbContext
`KoboProxyDbContext` should expose:
- `DbSet<KoboUser> KoboUsers`
- `DbSet<Form> Forms`
- `DbSet<FormVersion> FormVersions`
- `DbSet<Submission> Submissions`
- `DbSet<SubmissionMedia> SubmissionMedia`
- `DbSet<SyncLog> SyncLogs`

## Entity Highlights

### Submission
- Enum `SubmissionStatus`: Draft, Completed, PendingUpload, Synced, Failed.
- Unique index on `(FormVersionId, LocalInstanceId)`.
- Concurrency token rowversion for race-safe sync updates.

### FormVersion
- `XFormXml` stored as `nvarchar(max)` unchanged.
- `VersionHash` unique per form.

### SubmissionMedia
- Unique `(SubmissionId, FileName)`.
- `SortOrder` for deterministic multipart ordering.

## Example Fluent API Snippets

```csharp
modelBuilder.Entity<Submission>(b =>
{
    b.ToTable("Submissions");
    b.HasKey(x => x.Id);
    b.Property(x => x.Status)
        .HasConversion<string>()
        .HasMaxLength(32)
        .IsRequired();

    b.HasIndex(x => new { x.FormVersionId, x.LocalInstanceId }).IsUnique();
    b.Property<byte[]>("RowVersion").IsRowVersion();
});

modelBuilder.Entity<FormVersion>(b =>
{
    b.Property(x => x.XFormXml).HasColumnType("nvarchar(max)").IsRequired();
    b.HasIndex(x => new { x.FormId, x.VersionHash }).IsUnique();
});
```

## Migration Strategy
1. Initial migration from `sql/schema.sql` parity.
2. Add migration guard tests to verify critical indexes and constraints.
3. For large XML payload columns, enable PAGE compression based on DB edition.

