using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace ALIkhlasPOS.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddIsClosedToJournalEntry : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "IsClosed",
                table: "JournalEntries",
                type: "boolean",
                nullable: false,
                defaultValue: false);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "IsClosed",
                table: "JournalEntries");
        }
    }
}
