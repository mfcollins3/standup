// Copyright 2026 Michael F. Collins, III
// Licensed under the Naked Standup Source-Available Temporary License
// See LICENSE.md for license terms.

using Microsoft.EntityFrameworkCore;

namespace Api.Data;

public class StandupDbContext : DbContext
{
    public StandupDbContext(DbContextOptions<StandupDbContext> options) : base(options)
    {
    }

    public DbSet<Video> Videos { get; set; }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.Entity<Video>(entity =>
        {
            entity.ToTable("Videos");

            entity.HasKey(v => v.Id);
            entity.Property(v => v.Id)
                .HasColumnName("id")
                .ValueGeneratedNever();

            entity.Property(v => v.UserId)
                .HasColumnName("user_id")
                .IsRequired();

            entity.Property(v => v.BlobPath)
                .HasColumnName("blob_path")
                .HasMaxLength(1024)
                .IsRequired();

            entity.Property(v => v.ContentType)
                .HasColumnName("content_type")
                .HasMaxLength(256)
                .IsRequired();

            entity.Property(v => v.FileSizeBytes)
                .HasColumnName("file_size_bytes")
                .IsRequired();

            entity.Property(v => v.Status)
                .HasColumnName("status")
                .HasConversion<string>()
                .IsRequired();

            entity.Property(v => v.CloudflareVideoUid)
                .HasColumnName("cloudflare_video_uid")
                .HasMaxLength(256);

            entity.Property(v => v.HlsUrl)
                .HasColumnName("hls_url")
                .HasMaxLength(2048);

            entity.Property(v => v.DashUrl)
                .HasColumnName("dash_url")
                .HasMaxLength(2048);

            entity.Property(v => v.ThumbnailUrl)
                .HasColumnName("thumbnail_url")
                .HasMaxLength(2048);

            entity.Property(v => v.Duration)
                .HasColumnName("duration");

            entity.Property(v => v.InputWidth)
                .HasColumnName("input_width");

            entity.Property(v => v.InputHeight)
                .HasColumnName("input_height");

            entity.Property(v => v.ErrorReasonCode)
                .HasColumnName("error_reason_code")
                .HasMaxLength(256);

            entity.Property(v => v.ErrorReasonText)
                .HasColumnName("error_reason_text")
                .HasMaxLength(4096);

            entity.Property(v => v.CreatedAt)
                .HasColumnName("created_at")
                .IsRequired();

            entity.Property(v => v.UpdatedAt)
                .HasColumnName("updated_at")
                .IsRequired();

            entity.HasIndex(v => v.BlobPath)
                .IsUnique();

            entity.HasIndex(v => v.CloudflareVideoUid);
            entity.HasIndex(v => v.UserId);
            entity.HasIndex(v => v.Status);
        });
    }
}
