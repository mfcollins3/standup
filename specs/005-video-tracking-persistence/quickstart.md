# Quickstart: Video Tracking and Persistence

**Feature Branch**: `005-video-tracking-persistence`
**Prerequisites**: .NET 10 SDK, Azure Functions Core Tools v4, PostgreSQL 17

---

## 1. Install PostgreSQL Locally

### macOS (Homebrew)

```bash
brew install postgresql@17
brew services start postgresql@17
```

### Verify Installation

```bash
psql --version
# psql (PostgreSQL) 17.x
```

## 2. Create the Local Database

```bash
createdb standup
```

Connect and verify:

```bash
psql standup -c "SELECT version();"
```

## 3. Configure Local Settings

Add PostgreSQL connection settings to `api/local.settings.json`:

```json
{
  "Values": {
    "POSTGRESQL_HOST": "localhost",
    "POSTGRESQL_DATABASE": "standup",
    "POSTGRESQL_USERNAME": "<your-local-username>",
    "POSTGRESQL_PASSWORD": "<your-postgresql-password>"
  }
}
```

> **Note**: When running locally, `Program.cs` detects the `Development` environment and uses `POSTGRESQL_PASSWORD` for authentication instead of Entra managed identity tokens.

## 4. Install NuGet Packages

```bash
cd api
dotnet add package Npgsql.EntityFrameworkCore.PostgreSQL --version 10.0.1
dotnet add package Microsoft.EntityFrameworkCore.Design --version 10.0.5
dotnet restore
```

## 5. Create the Initial Migration

After implementing the `StandupDbContext` and `Video` entity:

```bash
cd api
dotnet ef migrations add InitialCreate
```

## 6. Apply Migration to Local Database

Generate and apply an idempotent SQL script:

```bash
dotnet ef migrations script --idempotent --output migrations.sql
psql standup -f migrations.sql
```

Or apply directly:

```bash
dotnet ef database update
```

Verify the table was created:

```bash
psql standup -c "\d \"Videos\""
```

## 7. Build and Run Locally

```bash
cd api
dotnet build
func start
```

The Function App runs at `http://localhost:7071`.

## 8. Test CreateVideo with Database Persistence

```bash
curl -s -X POST "http://localhost:7071/api/video" \
  -H "Content-Type: application/json" \
  -d '{"contentType": "video/mp4", "fileSizeBytes": 12345678}' | jq .
```

**Expected response**:

```json
{
  "videoId": "550e8400-e29b-41d4-a716-446655440000",
  "uploadUrl": "https://...",
  "expiresAt": "2026-03-24T15:00:00Z"
}
```

The `videoId` field is new. Verify the database record:

```bash
psql standup -c "SELECT id, status, blob_path, created_at FROM \"Videos\";"
```

Expected: One row with `status = 'Created'`.

## 9. Run Unit Tests

```bash
cd api
dotnet test
```

Unit tests use SQLite in-memory as the database provider so no running PostgreSQL instance is required for testing.

## 10. Deploy to Azure

### Provision PostgreSQL Infrastructure

```bash
azd provision
```

This deploys the new `postgresql.bicep` module which creates:
- Azure Database for PostgreSQL Flexible Server (B1ms, v17)
- Entra-only authentication (no password)
- Function App identity registered as database admin

### Post-Provisioning Setup

After `azd provision`, connect to the PostgreSQL server and run:

```sql
SELECT * FROM pgaadauth_create_principal('<function-app-name>', false, false);
GRANT ALL PRIVILEGES ON DATABASE standup TO "<function-app-name>";
```

### Apply Migrations to Azure

Generate the idempotent migration script and apply it to the Azure PostgreSQL instance:

```bash
dotnet ef migrations script --idempotent --output migrations.sql
psql "host=<server>.postgres.database.azure.com dbname=standup user=<your-entra-user> sslmode=require" -f migrations.sql
```

### Deploy Function Code

```bash
azd deploy
```

## 11. Verify End-to-End in Azure

1. Call the CreateVideo API — verify `videoId` in response and `Videos` table row with status `Created`
2. Upload a video blob to the SAS URL — Event Grid triggers ProcessVideo
3. ProcessVideo updates the Video record: status → `Processing`, `cloudflare_video_uid` set
4. Cloudflare transcodes and sends webhook → CloudflareWebhook updates Video: status → `Ready`, playback URLs stored
5. Query the database to confirm the full lifecycle:

```sql
SELECT id, status, cloudflare_video_uid, hls_url, dash_url, thumbnail_url
FROM "Videos"
ORDER BY created_at DESC
LIMIT 5;
```
