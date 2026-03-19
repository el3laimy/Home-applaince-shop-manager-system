using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace ALIkhlasPOS.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddInvoiceSequenceAndIndex : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateSequence(
                name: "internal_barcode_seq");

            migrationBuilder.CreateSequence(
                name: "invoice_seq");

            migrationBuilder.CreateSequence(
                name: "voucher_seq");

            migrationBuilder.CreateIndex(
                name: "IX_Invoices_InvoiceNo",
                table: "Invoices",
                column: "InvoiceNo",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Invoices_InvoiceNo",
                table: "Invoices");

            migrationBuilder.DropSequence(
                name: "internal_barcode_seq");

            migrationBuilder.DropSequence(
                name: "invoice_seq");

            migrationBuilder.DropSequence(
                name: "voucher_seq");
        }
    }
}
