using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace ALIkhlasPOS.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddPaymentReferenceToInvoice : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.RenameColumn(
                name: "FittingDate",
                table: "Invoices",
                newName: "DeliveryDate");

            migrationBuilder.RenameColumn(
                name: "DressDetails",
                table: "Invoices",
                newName: "PaymentReference");

            migrationBuilder.AddColumn<string>(
                name: "BridalNotes",
                table: "Invoices",
                type: "text",
                nullable: true);

            migrationBuilder.AddColumn<int>(
                name: "InstallmentCount",
                table: "Invoices",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<int>(
                name: "InstallmentPeriod",
                table: "Invoices",
                type: "integer",
                nullable: false,
                defaultValue: 0);

            migrationBuilder.AddColumn<decimal>(
                name: "InterestRate",
                table: "Invoices",
                type: "numeric",
                nullable: false,
                defaultValue: 0m);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "BridalNotes",
                table: "Invoices");

            migrationBuilder.DropColumn(
                name: "InstallmentCount",
                table: "Invoices");

            migrationBuilder.DropColumn(
                name: "InstallmentPeriod",
                table: "Invoices");

            migrationBuilder.DropColumn(
                name: "InterestRate",
                table: "Invoices");

            migrationBuilder.RenameColumn(
                name: "PaymentReference",
                table: "Invoices",
                newName: "DressDetails");

            migrationBuilder.RenameColumn(
                name: "DeliveryDate",
                table: "Invoices",
                newName: "FittingDate");
        }
    }
}
