using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace SaHaBaHealth.Api.Migrations
{
    /// <inheritdoc />
    public partial class AddMedicationLogs : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_MedicationLogs_medication_schedules_ScheduleId",
                table: "MedicationLogs");

            migrationBuilder.DropPrimaryKey(
                name: "PK_MedicationLogs",
                table: "MedicationLogs");

            migrationBuilder.DropColumn(
                name: "is_taken",
                table: "medication_schedules");

            migrationBuilder.RenameTable(
                name: "MedicationLogs",
                newName: "medication_logs");

            migrationBuilder.RenameColumn(
                name: "Id",
                table: "medication_logs",
                newName: "id");

            migrationBuilder.RenameColumn(
                name: "ScheduleId",
                table: "medication_logs",
                newName: "schedule_id");

            migrationBuilder.RenameColumn(
                name: "LogDate",
                table: "medication_logs",
                newName: "log_date");

            migrationBuilder.RenameColumn(
                name: "IsTaken",
                table: "medication_logs",
                newName: "is_taken");

            migrationBuilder.RenameIndex(
                name: "IX_MedicationLogs_ScheduleId",
                table: "medication_logs",
                newName: "IX_medication_logs_schedule_id");

            migrationBuilder.AddColumn<DateTime>(
                name: "created_at",
                table: "medication_logs",
                type: "timestamp with time zone",
                nullable: false,
                defaultValue: new DateTime(1, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified));

            migrationBuilder.AddPrimaryKey(
                name: "PK_medication_logs",
                table: "medication_logs",
                column: "id");

            migrationBuilder.AddForeignKey(
                name: "FK_medication_logs_medication_schedules_schedule_id",
                table: "medication_logs",
                column: "schedule_id",
                principalTable: "medication_schedules",
                principalColumn: "id",
                onDelete: ReferentialAction.Cascade);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_medication_logs_medication_schedules_schedule_id",
                table: "medication_logs");

            migrationBuilder.DropPrimaryKey(
                name: "PK_medication_logs",
                table: "medication_logs");

            migrationBuilder.DropColumn(
                name: "created_at",
                table: "medication_logs");

            migrationBuilder.RenameTable(
                name: "medication_logs",
                newName: "MedicationLogs");

            migrationBuilder.RenameColumn(
                name: "id",
                table: "MedicationLogs",
                newName: "Id");

            migrationBuilder.RenameColumn(
                name: "schedule_id",
                table: "MedicationLogs",
                newName: "ScheduleId");

            migrationBuilder.RenameColumn(
                name: "log_date",
                table: "MedicationLogs",
                newName: "LogDate");

            migrationBuilder.RenameColumn(
                name: "is_taken",
                table: "MedicationLogs",
                newName: "IsTaken");

            migrationBuilder.RenameIndex(
                name: "IX_medication_logs_schedule_id",
                table: "MedicationLogs",
                newName: "IX_MedicationLogs_ScheduleId");

            migrationBuilder.AddColumn<bool>(
                name: "is_taken",
                table: "medication_schedules",
                type: "boolean",
                nullable: false,
                defaultValue: false);

            migrationBuilder.AddPrimaryKey(
                name: "PK_MedicationLogs",
                table: "MedicationLogs",
                column: "Id");

            migrationBuilder.AddForeignKey(
                name: "FK_MedicationLogs_medication_schedules_ScheduleId",
                table: "MedicationLogs",
                column: "ScheduleId",
                principalTable: "medication_schedules",
                principalColumn: "id",
                onDelete: ReferentialAction.Cascade);
        }
    }
}
