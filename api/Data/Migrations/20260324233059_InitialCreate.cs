using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace Standup.Api.Data.Migrations
{
    /// <inheritdoc />
    public partial class InitialCreate : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "Videos",
                columns: table => new
                {
                    id = table.Column<Guid>(type: "uuid", nullable: false),
                    user_id = table.Column<Guid>(type: "uuid", nullable: false),
                    blob_path = table.Column<string>(type: "character varying(1024)", maxLength: 1024, nullable: false),
                    content_type = table.Column<string>(type: "character varying(256)", maxLength: 256, nullable: false),
                    file_size_bytes = table.Column<long>(type: "bigint", nullable: false),
                    status = table.Column<string>(type: "text", nullable: false),
                    cloudflare_video_uid = table.Column<string>(type: "character varying(256)", maxLength: 256, nullable: true),
                    hls_url = table.Column<string>(type: "character varying(2048)", maxLength: 2048, nullable: true),
                    dash_url = table.Column<string>(type: "character varying(2048)", maxLength: 2048, nullable: true),
                    thumbnail_url = table.Column<string>(type: "character varying(2048)", maxLength: 2048, nullable: true),
                    duration = table.Column<double>(type: "double precision", nullable: true),
                    input_width = table.Column<int>(type: "integer", nullable: true),
                    input_height = table.Column<int>(type: "integer", nullable: true),
                    error_reason_code = table.Column<string>(type: "character varying(256)", maxLength: 256, nullable: true),
                    error_reason_text = table.Column<string>(type: "character varying(4096)", maxLength: 4096, nullable: true),
                    created_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false),
                    updated_at = table.Column<DateTimeOffset>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Videos", x => x.id);
                });

            migrationBuilder.CreateIndex(
                name: "IX_Videos_blob_path",
                table: "Videos",
                column: "blob_path",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Videos_cloudflare_video_uid",
                table: "Videos",
                column: "cloudflare_video_uid");

            migrationBuilder.CreateIndex(
                name: "IX_Videos_status",
                table: "Videos",
                column: "status");

            migrationBuilder.CreateIndex(
                name: "IX_Videos_user_id",
                table: "Videos",
                column: "user_id");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "Videos");
        }
    }
}
