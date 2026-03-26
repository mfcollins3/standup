// Copyright 2026 Michael F. Collins, III
// Licensed under the Naked Standup Source-Available Temporary License
// See LICENSE.md for license terms.

using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace Api.Data;

/// <summary>
/// Design-time factory used by the EF Core CLI tools (dotnet ef migrations).
/// Not used at runtime.
/// </summary>
public class DesignTimeStandupDbContextFactory : IDesignTimeDbContextFactory<StandupDbContext>
{
    public StandupDbContext CreateDbContext(string[] args)
    {
        var options = new DbContextOptionsBuilder<StandupDbContext>()
            .UseNpgsql("Host=localhost;Database=standup;Username=standup")
            .Options;
        return new StandupDbContext(options);
    }
}
