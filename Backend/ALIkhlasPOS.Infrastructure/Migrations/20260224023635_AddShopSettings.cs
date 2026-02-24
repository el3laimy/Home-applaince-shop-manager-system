using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace ALIkhlasPOS.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddShopSettings : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Invoices_Customers_CustomerId1",
                table: "Invoices");

            migrationBuilder.DropIndex(
                name: "IX_Invoices_CustomerId1",
                table: "Invoices");

            migrationBuilder.DropColumn(
                name: "CustomerId1",
                table: "Invoices");

            migrationBuilder.CreateTable(
                name: "ShopSettings",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "uuid", nullable: false),
                    ShopName = table.Column<string>(type: "character varying(200)", maxLength: 200, nullable: false),
                    Address = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    Phone = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: true),
                    Phone2 = table.Column<string>(type: "character varying(20)", maxLength: 20, nullable: true),
                    CommercialRegNo = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: true),
                    TaxNumber = table.Column<string>(type: "character varying(50)", maxLength: 50, nullable: true),
                    LogoBase64 = table.Column<string>(type: "text", nullable: true),
                    ReceiptFooter = table.Column<string>(type: "character varying(500)", maxLength: 500, nullable: true),
                    VatEnabled = table.Column<bool>(type: "boolean", nullable: false),
                    DefaultVatRate = table.Column<decimal>(type: "numeric(5,2)", nullable: false),
                    CurrencySymbol = table.Column<string>(type: "character varying(10)", maxLength: 10, nullable: false),
                    CurrencyCode = table.Column<string>(type: "character varying(10)", maxLength: 10, nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "timestamp with time zone", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_ShopSettings", x => x.Id);
                });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "ShopSettings");

            migrationBuilder.AddColumn<Guid>(
                name: "CustomerId1",
                table: "Invoices",
                type: "uuid",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_Invoices_CustomerId1",
                table: "Invoices",
                column: "CustomerId1");

            migrationBuilder.AddForeignKey(
                name: "FK_Invoices_Customers_CustomerId1",
                table: "Invoices",
                column: "CustomerId1",
                principalTable: "Customers",
                principalColumn: "Id");
        }
    }
}
