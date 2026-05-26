using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SaHaBaHealth.Api.Migrations
{
    /// <inheritdoc />
    public partial class ForceFixIsTaken : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Lệnh SQL ép đục thẳng vào Database để thêm cột is_taken
            migrationBuilder.Sql("ALTER TABLE medication_schedules ADD COLUMN IF NOT EXISTS is_taken boolean NOT NULL DEFAULT false;");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            // Lệnh SQL để gỡ bỏ cột nếu sau này bạn muốn lùi lại (rollback)
            migrationBuilder.Sql("ALTER TABLE medication_schedules DROP COLUMN IF EXISTS is_taken;");
        }
    }
}