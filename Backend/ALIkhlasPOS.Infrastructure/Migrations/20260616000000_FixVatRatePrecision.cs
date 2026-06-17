using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace ALIkhlasPOS.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class FixVatRatePrecision : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AlterColumn<decimal>(
                name: "VatRate",
                table: "Invoices",
                type: "numeric(7,4)",
                nullable: false,
                oldClrType: typeof(decimal),
                oldType: "numeric(5,4)");

            migrationBuilder.AlterColumn<decimal>(
                name: "DefaultVatRate",
                table: "ShopSettings",
                type: "numeric(7,4)",
                nullable: false,
                oldClrType: typeof(decimal),
                oldType: "numeric(5,4)");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AlterColumn<decimal>(
                name: "VatRate",
                table: "Invoices",
                type: "numeric(5,4)",
                nullable: false,
                oldClrType: typeof(decimal),
                oldType: "numeric(7,4)");

            migrationBuilder.AlterColumn<decimal>(
                name: "DefaultVatRate",
                table: "ShopSettings",
                type: "numeric(5,4)",
                nullable: false,
                oldClrType: typeof(decimal),
                oldType: "numeric(7,4)");
        }
    }
}
