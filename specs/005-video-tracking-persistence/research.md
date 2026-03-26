# Research: Video Tracking and Persistence

**Feature Branch**: `005-video-tracking-persistence`
**Date**: 2026-03-24

## 1. Database Technology Selection

- **Decision**: Azure Database for PostgreSQL Flexible Server (Burstable B1ms, 32 GB, PostgreSQL 17)
- **Rationale**: Supports the future polyglot stack — Go (GORM), Rust (sea-orm), and Elixir/Phoenix (Ecto) all have mature PostgreSQL support. Ecto has no SQL Server adapter and sea-orm has no SQL Server support, ruling out Azure SQL. Cosmos DB was rejected due to multi-dimensional filtering needs and the relational trajectory of the data model.
- **Alternatives considered**:
  - Azure Cosmos DB (NoSQL): Too expensive for relational queries; poor fit for multi-dimensional filtering
  - Azure Cosmos DB (MongoDB vCore): Overkill for current needs; more complex than necessary
  - Azure SQL Database (free tier): No Ecto adapter (Elixir), no sea-orm support (Rust)
  - Azure SQL Database (paid): Same polyglot limitations plus higher cost than PostgreSQL

## 2. ORM and Data Access

- **Decision**: Entity Framework Core 10 with Npgsql.EntityFrameworkCore.PostgreSQL 10.0.1
- **Rationale**: EF Core is the standard .NET ORM with first-class PostgreSQL support via Npgsql. The version tracks EF Core major version (10.x ↔ EF Core 10). Npgsql brings the ADO.NET driver transitively.
- **Alternatives considered**:
  - Dapper: Lower-level, no migration support, manual SQL — unnecessary friction for CRUD operations
  - Raw ADO.NET / Npgsql: Too verbose for simple entity persistence; no migration tooling

## 3. Serverless DbContext Pattern

- **Decision**: `IDbContextFactory<StandupDbContext>` with `AddDbContextFactory()` registration
- **Rationale**: In Azure Functions isolated worker, each invocation should create and dispose its own DbContext to avoid concurrency issues and connection leaks. `AddDbContextFactory` is the documented best practice for this scenario. Direct `AddDbContext<T>()` (scoped lifetime) misaligns with serverless invocation patterns. `AddDbContextPoolFactory` is incompatible with the periodic password provider needed for managed identity token rotation.
- **Alternatives considered**:
  - `AddDbContext<T>()` (scoped injection): Lifetime scoping doesn't align with serverless invocations
  - `AddDbContextPool` / `AddDbContextPoolFactory`: Incompatible with `UsePeriodicPasswordProvider` for Entra token rotation

## 4. Authentication to PostgreSQL

- **Decision**: Microsoft Entra ID managed identity authentication using Npgsql's `UsePeriodicPasswordProvider`
- **Rationale**: Aligns with the project's "Security by Default" constitution principle — no passwords in configuration or code. The Function App's system-assigned managed identity obtains an OAuth2 token targeting `https://ossrdbms-aad.database.windows.net/.default` and passes it as the password via Npgsql's periodic provider. Tokens expire at 60 minutes; the provider refreshes every 55 minutes.
- **Connection string format**: `Host={fqdn};Database=standup;Username={functionAppName};Ssl Mode=Require;Trust Server Certificate=true`
- **Token scope**: `https://ossrdbms-aad.database.windows.net/.default`
- **Refresh interval**: 55 minutes (tokens expire at 60 minutes)
- **Server-side setup** (one-time, run as Entra admin on `postgres` database):
  ```sql
  SELECT * FROM pgaadauth_create_principal('<function-app-name>', false, false);
  GRANT ALL PRIVILEGES ON DATABASE standup TO "<function-app-name>";
  ```
- **Alternatives considered**:
  - Password authentication: Violates security constitution; requires secret rotation
  - `UsePasswordProvider` (per-connection token): Works but `UsePeriodicPasswordProvider` is more explicit about caching

## 5. NuGet Packages Required

| Package | Version | Purpose |
|---------|---------|---------|
| `Npgsql.EntityFrameworkCore.PostgreSQL` | 10.0.1 | EF Core provider for PostgreSQL |
| `Azure.Identity` | 1.13.2 (already referenced) | `DefaultAzureCredential` for Entra token acquisition |
| `Microsoft.EntityFrameworkCore.Design` | 10.0.5 | `dotnet ef` CLI migrations tooling (PrivateAssets=all) |

Note: `Azure.Identity` is already in the project at version 1.13.2. The research found 1.19.0 is available, but upgrading is out of scope for this feature.

## 6. EF Core Migrations Strategy

- **Decision**: Idempotent SQL scripts for this feature; migration bundles deferred to CI/CD pipeline feature
- **Rationale**: Running `dotnet ef migrations script --idempotent` generates a single SQL script that can be reviewed and applied manually. This is appropriate for the current stage with no CI/CD pipeline for database migrations. Migration bundles (self-contained executables) are the recommended long-term approach but add pipeline complexity that is out of scope.
- **Migration generation**: `dotnet ef migrations add InitialCreate --project api`
- **Script generation**: `dotnet ef migrations script --idempotent --project api --output migrations.sql`
- **Alternatives considered**:
  - Migration bundles (`dotnet ef migrations bundle`): Best for CI/CD but adds pipeline infrastructure
  - Runtime migration (`MigrateAsync()`): Not recommended for serverless — multiple cold-starting instances can race

## 7. Unit Testing Approach

- **Decision**: Mock `IDbContextFactory<StandupDbContext>` with SQLite in-memory as the backing store for unit tests
- **Rationale**: Microsoft discourages the EF Core InMemory provider ("significant differences compared to a real database"). SQLite in-memory provides better relational behavior while remaining fast and requiring no external dependencies. For Azure Functions unit tests, mock the factory to return a context backed by SQLite in-memory.
- **SQLite configuration**: `options.UseSqlite("DataSource=:memory:")` with `context.Database.OpenConnection()` and `context.Database.EnsureCreated()` — the connection must stay open for the database to persist during the test.
- **Test NuGet package**: `Microsoft.EntityFrameworkCore.Sqlite` (for test project only)
- **Alternatives considered**:
  - EF Core InMemory provider: Officially discouraged; behavior differences with real databases
  - Testcontainers.PostgreSql: Full fidelity but adds Docker dependency and slower test runs; better for integration tests (deferred)

## 8. Bicep Resource Provisioning

- **Decision**: `Microsoft.DBforPostgreSQL/flexibleServers@2024-08-01` with Entra-only auth
- **Rationale**: This is the latest GA API version. The 2026-01-01-preview is available but not recommended for production.
- **Key Bicep configuration**:
  - `authConfig.activeDirectoryAuth`: `'Enabled'`
  - `authConfig.passwordAuth`: `'Disabled'`
  - `authConfig.tenantId`: `subscription().tenantId`
  - `sku.name`: `'Standard_B1ms'` (Burstable tier)
  - `storage.storageSizeGB`: `32`
  - `version`: `'17'`
- **Entra admin assignment**: Child resource `Microsoft.DBforPostgreSQL/flexibleServers/administrators@2024-08-01` designating the Function App's managed identity as an Entra admin
- **Abbreviation**: `postgreSqlFlexibleServer` → `psql` (to be added to `abbreviations.json`)

## 9. Cold-Start Impact Assessment

- **Decision**: No special mitigation required at this stage
- **Rationale**: For a simple model (1 entity), EF Core model building adds ~200-500ms to cold start, plus ~100-300ms for the first database connection (TLS handshake). This is well within the FC1 30-second initialization timeout. The current 2048 MB (1 vCPU) instance size is appropriate. Always-ready instances or compiled models are unnecessary optimizations at this stage.
- **Future considerations**: If cold starts become problematic, consider always-ready instances (FC1 supports 1+ baseline instances) or `dotnet ef dbcontext optimize` for compiled models (matters for 100+ entities).

## 10. Connection String Configuration

- **Decision**: Store the PostgreSQL FQDN and database name in Function App settings; construct NpgsqlDataSource in DI with token provider
- **Rationale**: The connection string itself contains no secrets (no password). The FQDN and database name can safely live in app settings. The managed identity token is obtained at runtime via `DefaultAzureCredential`. This follows the existing pattern where `AZURE_STORAGE_BLOB_ENDPOINT` is stored as a plain app setting.
- **App settings to add**:
  - `POSTGRESQL_HOST`: The PostgreSQL server FQDN (e.g., `psql-standup-{env}.postgres.database.azure.com`)
  - `POSTGRESQL_DATABASE`: `standup`
  - `POSTGRESQL_USERNAME`: The Function App name (for Entra username in connection string)
