using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace ALIkhlasPOS.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class FixPurchaseProductIdType : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_PurchaseInvoiceItems_Products_ProductId1",
                table: "PurchaseInvoiceItems");

            migrationBuilder.DropIndex(
                name: "IX_PurchaseInvoiceItems_ProductId1",
                table: "PurchaseInvoiceItems");

            migrationBuilder.DropColumn(
                name: "ProductId1",
                table: "PurchaseInvoiceItems");

            // AlterColumn cannot auto-cast text/int → uuid in PostgreSQL.
            // Use raw SQL with the required USING clause instead.
            migrationBuilder.Sql("ALTER TABLE \"PurchaseInvoiceItems\" ALTER COLUMN \"ProductId\" TYPE uuid USING \"ProductId\"::text::uuid;");

            migrationBuilder.CreateIndex(
                name: "IX_PurchaseInvoiceItems_ProductId",
                table: "PurchaseInvoiceItems",
                column: "ProductId");

            migrationBuilder.AddForeignKey(
                name: "FK_PurchaseInvoiceItems_Products_ProductId",
                table: "PurchaseInvoiceItems",
                column: "ProductId",
                principalTable: "Products",
                principalColumn: "Id",
                onDelete: ReferentialAction.Cascade);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_PurchaseInvoiceItems_Products_ProductId",
                table: "PurchaseInvoiceItems");

            migrationBuilder.DropIndex(
                name: "IX_PurchaseInvoiceItems_ProductId",
                table: "PurchaseInvoiceItems");

            migrationBuilder.AlterColumn<int>(
                name: "ProductId",
                table: "PurchaseInvoiceItems",
                type: "integer",
                nullable: false,
                oldClrType: typeof(Guid),
                oldType: "uuid");

            migrationBuilder.AddColumn<Guid>(
                name: "ProductId1",
                table: "PurchaseInvoiceItems",
                type: "uuid",
                nullable: true);

            migrationBuilder.CreateIndex(
                name: "IX_PurchaseInvoiceItems_ProductId1",
                table: "PurchaseInvoiceItems",
                column: "ProductId1");

            migrationBuilder.AddForeignKey(
                name: "FK_PurchaseInvoiceItems_Products_ProductId1",
                table: "PurchaseInvoiceItems",
                column: "ProductId1",
                principalTable: "Products",
                principalColumn: "Id");
        }
    }
}
