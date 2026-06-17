using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace ALIkhlasPOS.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class AddInstallmentAndBridalFieldsToInvoice : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Rename bridal fields to be more generic (home appliances)
            migrationBuilder.RenameColumn(
                name: "FittingDate",
                table: "Invoices",
                newName: "DeliveryDate");

            migrationBuilder.RenameColumn(
                name: "DressDetails",
                table: "Invoices",
                newName: "BridalNotes");

            // Installment interest rate fields
            migrationBuilder.AddColumn<decimal>(
                name: "InterestRate",
                table: "Invoices",
                type: "numeric",
                nullable: false,
                defaultValue: 0m);

            migrationBuilder.AddColumn<int>(
                name: "InstallmentPeriod",
                table: "Invoices",
                type: "integer",
                nullable: false,
                defaultValue: 0); // Monthly = 0

            migrationBuilder.AddColumn<int>(
                name: "InstallmentCount",
                table: "Invoices",
                type: "integer",
                nullable: false,
                defaultValue: 0);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.RenameColumn(
                name: "DeliveryDate",
                table: "Invoices",
                newName: "FittingDate");

            migrationBuilder.RenameColumn(
                name: "BridalNotes",
                table: "Invoices",
                newName: "DressDetails");

            migrationBuilder.DropColumn(
                name: "InterestRate",
                table: "Invoices");

            migrationBuilder.DropColumn(
                name: "InstallmentPeriod",
                table: "Invoices");

            migrationBuilder.DropColumn(
                name: "InstallmentCount",
                table: "Invoices");
        }
    }
}
