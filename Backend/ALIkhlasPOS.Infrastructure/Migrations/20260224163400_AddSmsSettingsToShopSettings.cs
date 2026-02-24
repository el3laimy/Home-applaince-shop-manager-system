using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace ALIkhlasPOS.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddSmsSettingsToShopSettings : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<string>(
                name: "SmsApiKey",
                table: "ShopSettings",
                type: "character varying(500)",
                maxLength: 500,
                nullable: true);

            migrationBuilder.AddColumn<string>(
                name: "SmsSenderId",
                table: "ShopSettings",
                type: "character varying(100)",
                maxLength: 100,
                nullable: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "SmsApiKey",
                table: "ShopSettings");

            migrationBuilder.DropColumn(
                name: "SmsSenderId",
                table: "ShopSettings");
        }
    }
}
