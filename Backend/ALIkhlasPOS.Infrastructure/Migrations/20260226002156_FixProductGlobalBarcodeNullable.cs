using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace ALIkhlasPOS.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class FixProductGlobalBarcodeNullable : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Products_GlobalBarcode",
                table: "Products");

            migrationBuilder.AlterColumn<string>(
                name: "GlobalBarcode",
                table: "Products",
                type: "text",
                nullable: true,
                oldClrType: typeof(string),
                oldType: "text");

            migrationBuilder.CreateIndex(
                name: "IX_Products_GlobalBarcode",
                table: "Products",
                column: "GlobalBarcode",
                unique: true,
                filter: "\"GlobalBarcode\" IS NOT NULL");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Products_GlobalBarcode",
                table: "Products");

            migrationBuilder.AlterColumn<string>(
                name: "GlobalBarcode",
                table: "Products",
                type: "text",
                nullable: false,
                defaultValue: "",
                oldClrType: typeof(string),
                oldType: "text",
                oldNullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_Products_GlobalBarcode",
                table: "Products",
                column: "GlobalBarcode",
                unique: true);
        }
    }
}
