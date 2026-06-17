using System;
using Microsoft.EntityFrameworkCore.Migrations;
using Npgsql.EntityFrameworkCore.PostgreSQL.Metadata;

#nullable disable

namespace ALIkhlasPOS.Infrastructure.Migrations
{
    /// <inheritdoc />
    public partial class UnifyGuidIds_InvoiceFields_BCrypt : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // ── Step 1: Drop all FK constraints that reference integer-typed columns ──
            migrationBuilder.Sql("ALTER TABLE \"Suppliers\" DROP CONSTRAINT IF EXISTS \"FK_Suppliers_Accounts_AccountId\";");
            migrationBuilder.Sql("ALTER TABLE \"PurchaseInvoices\" DROP CONSTRAINT IF EXISTS \"FK_PurchaseInvoices_Suppliers_SupplierId\";");
            migrationBuilder.Sql("ALTER TABLE \"PurchaseInvoices\" DROP CONSTRAINT IF EXISTS \"FK_PurchaseInvoices_JournalEntries_JournalEntryId\";");
            migrationBuilder.Sql("ALTER TABLE \"PurchaseInvoiceItems\" DROP CONSTRAINT IF EXISTS \"FK_PurchaseInvoiceItems_PurchaseInvoices_PurchaseInvoiceId\";");
            migrationBuilder.Sql("ALTER TABLE \"JournalEntryLines\" DROP CONSTRAINT IF EXISTS \"FK_JournalEntryLines_JournalEntries_JournalEntryId\";");
            migrationBuilder.Sql("ALTER TABLE \"JournalEntryLines\" DROP CONSTRAINT IF EXISTS \"FK_JournalEntryLines_Accounts_AccountId\";");
            migrationBuilder.Sql("ALTER TABLE \"Expenses\" DROP CONSTRAINT IF EXISTS \"FK_Expenses_JournalEntries_JournalEntryId\";");
            migrationBuilder.Sql("ALTER TABLE \"CashTransactions\" DROP CONSTRAINT IF EXISTS \"FK_CashTransactions_Accounts_TargetAccountId\";");
            migrationBuilder.Sql("ALTER TABLE \"CashTransactions\" DROP CONSTRAINT IF EXISTS \"FK_CashTransactions_JournalEntries_JournalEntryId\";");
            migrationBuilder.Sql("ALTER TABLE \"Accounts\" DROP CONSTRAINT IF EXISTS \"FK_Accounts_Accounts_ParentAccountId\";");

            // ── Step 2: Drop indexes on FK columns ──
            migrationBuilder.Sql("DROP INDEX IF EXISTS \"IX_Suppliers_AccountId\";");
            migrationBuilder.Sql("DROP INDEX IF EXISTS \"IX_PurchaseInvoices_SupplierId\";");
            migrationBuilder.Sql("DROP INDEX IF EXISTS \"IX_PurchaseInvoices_JournalEntryId\";");
            migrationBuilder.Sql("DROP INDEX IF EXISTS \"IX_PurchaseInvoiceItems_PurchaseInvoiceId\";");
            migrationBuilder.Sql("DROP INDEX IF EXISTS \"IX_JournalEntryLines_JournalEntryId\";");
            migrationBuilder.Sql("DROP INDEX IF EXISTS \"IX_JournalEntryLines_AccountId\";");
            migrationBuilder.Sql("DROP INDEX IF EXISTS \"IX_Expenses_JournalEntryId\";");
            migrationBuilder.Sql("DROP INDEX IF EXISTS \"IX_CashTransactions_TargetAccountId\";");
            migrationBuilder.Sql("DROP INDEX IF EXISTS \"IX_CashTransactions_JournalEntryId\";");
            migrationBuilder.Sql("DROP INDEX IF EXISTS \"IX_Accounts_ParentAccountId\";");

            // ── Step 3: Cast all integer IDs → uuid ──
            // Accounts — drop IDENTITY before uuid cast
            migrationBuilder.Sql("ALTER TABLE \"Accounts\" ALTER COLUMN \"Id\" DROP IDENTITY IF EXISTS;");
            migrationBuilder.Sql("ALTER TABLE \"Accounts\" ALTER COLUMN \"Id\" TYPE uuid USING \"Id\"::text::uuid;");
            migrationBuilder.Sql("ALTER TABLE \"Accounts\" ALTER COLUMN \"ParentAccountId\" TYPE uuid USING \"ParentAccountId\"::text::uuid;");

            // Suppliers — drop IDENTITY before uuid cast
            migrationBuilder.Sql("ALTER TABLE \"Suppliers\" ALTER COLUMN \"Id\" DROP IDENTITY IF EXISTS;");
            migrationBuilder.Sql("ALTER TABLE \"Suppliers\" ALTER COLUMN \"Id\" TYPE uuid USING \"Id\"::text::uuid;");
            migrationBuilder.Sql("ALTER TABLE \"Suppliers\" ALTER COLUMN \"AccountId\" TYPE uuid USING \"AccountId\"::text::uuid;");

            // JournalEntries — drop IDENTITY before uuid cast
            migrationBuilder.Sql("ALTER TABLE \"JournalEntries\" ALTER COLUMN \"Id\" DROP IDENTITY IF EXISTS;");
            migrationBuilder.Sql("ALTER TABLE \"JournalEntries\" ALTER COLUMN \"Id\" TYPE uuid USING \"Id\"::text::uuid;");

            // JournalEntryLines
            migrationBuilder.Sql("ALTER TABLE \"JournalEntryLines\" ALTER COLUMN \"Id\" DROP IDENTITY IF EXISTS;");
            migrationBuilder.Sql("ALTER TABLE \"JournalEntryLines\" ALTER COLUMN \"Id\" TYPE uuid USING \"Id\"::text::uuid;");
            migrationBuilder.Sql("ALTER TABLE \"JournalEntryLines\" ALTER COLUMN \"JournalEntryId\" TYPE uuid USING \"JournalEntryId\"::text::uuid;");
            migrationBuilder.Sql("ALTER TABLE \"JournalEntryLines\" ALTER COLUMN \"AccountId\" TYPE uuid USING \"AccountId\"::text::uuid;");

            // Expenses
            migrationBuilder.Sql("ALTER TABLE \"Expenses\" ALTER COLUMN \"Id\" DROP IDENTITY IF EXISTS;");
            migrationBuilder.Sql("ALTER TABLE \"Expenses\" ALTER COLUMN \"Id\" TYPE uuid USING \"Id\"::text::uuid;");
            migrationBuilder.Sql("ALTER TABLE \"Expenses\" ALTER COLUMN \"JournalEntryId\" TYPE uuid USING \"JournalEntryId\"::text::uuid;");

            // CashTransactions
            migrationBuilder.Sql("ALTER TABLE \"CashTransactions\" ALTER COLUMN \"Id\" DROP IDENTITY IF EXISTS;");
            migrationBuilder.Sql("ALTER TABLE \"CashTransactions\" ALTER COLUMN \"Id\" TYPE uuid USING \"Id\"::text::uuid;");
            migrationBuilder.Sql("ALTER TABLE \"CashTransactions\" ALTER COLUMN \"TargetAccountId\" TYPE uuid USING \"TargetAccountId\"::text::uuid;");
            migrationBuilder.Sql("ALTER TABLE \"CashTransactions\" ALTER COLUMN \"JournalEntryId\" TYPE uuid USING \"JournalEntryId\"::text::uuid;");

            // PurchaseInvoices
            migrationBuilder.Sql("ALTER TABLE \"PurchaseInvoices\" ALTER COLUMN \"Id\" DROP IDENTITY IF EXISTS;");
            migrationBuilder.Sql("ALTER TABLE \"PurchaseInvoices\" ALTER COLUMN \"Id\" TYPE uuid USING \"Id\"::text::uuid;");
            migrationBuilder.Sql("ALTER TABLE \"PurchaseInvoices\" ALTER COLUMN \"SupplierId\" TYPE uuid USING \"SupplierId\"::text::uuid;");
            migrationBuilder.Sql("ALTER TABLE \"PurchaseInvoices\" ALTER COLUMN \"JournalEntryId\" TYPE uuid USING \"JournalEntryId\"::text::uuid;");

            // PurchaseInvoiceItems
            migrationBuilder.Sql("ALTER TABLE \"PurchaseInvoiceItems\" ALTER COLUMN \"Id\" DROP IDENTITY IF EXISTS;");
            migrationBuilder.Sql("ALTER TABLE \"PurchaseInvoiceItems\" ALTER COLUMN \"Id\" TYPE uuid USING \"Id\"::text::uuid;");
            migrationBuilder.Sql("ALTER TABLE \"PurchaseInvoiceItems\" ALTER COLUMN \"PurchaseInvoiceId\" TYPE uuid USING \"PurchaseInvoiceId\"::text::uuid;");

            // ── Step 4: Alter decimal precision columns ──
            migrationBuilder.AlterColumn<decimal>(name: "OpeningBalance", table: "Suppliers", type: "numeric(18,2)", nullable: false, oldClrType: typeof(decimal), oldType: "numeric");
            migrationBuilder.AlterColumn<decimal>(name: "TotalAmount", table: "PurchaseInvoices", type: "numeric(18,2)", nullable: false, oldClrType: typeof(decimal), oldType: "numeric");
            migrationBuilder.AlterColumn<decimal>(name: "RemainingAmount", table: "PurchaseInvoices", type: "numeric(18,2)", nullable: false, oldClrType: typeof(decimal), oldType: "numeric");
            migrationBuilder.AlterColumn<decimal>(name: "PaidAmount", table: "PurchaseInvoices", type: "numeric(18,2)", nullable: false, oldClrType: typeof(decimal), oldType: "numeric");
            migrationBuilder.AlterColumn<decimal>(name: "NetAmount", table: "PurchaseInvoices", type: "numeric(18,2)", nullable: false, oldClrType: typeof(decimal), oldType: "numeric");
            migrationBuilder.AlterColumn<decimal>(name: "Discount", table: "PurchaseInvoices", type: "numeric(18,2)", nullable: false, oldClrType: typeof(decimal), oldType: "numeric");
            migrationBuilder.AlterColumn<decimal>(name: "UnitPrice", table: "PurchaseInvoiceItems", type: "numeric(18,2)", nullable: false, oldClrType: typeof(decimal), oldType: "numeric");
            migrationBuilder.AlterColumn<decimal>(name: "TotalPrice", table: "PurchaseInvoiceItems", type: "numeric(18,2)", nullable: false, oldClrType: typeof(decimal), oldType: "numeric");
            migrationBuilder.AlterColumn<decimal>(name: "Debit", table: "JournalEntryLines", type: "numeric(18,2)", nullable: false, oldClrType: typeof(decimal), oldType: "numeric");
            migrationBuilder.AlterColumn<decimal>(name: "Credit", table: "JournalEntryLines", type: "numeric(18,2)", nullable: false, oldClrType: typeof(decimal), oldType: "numeric");
            migrationBuilder.AlterColumn<decimal>(name: "DiscountAmount", table: "Invoices", type: "numeric(18,2)", nullable: false, oldClrType: typeof(decimal), oldType: "numeric");
            migrationBuilder.AlterColumn<decimal>(name: "Amount", table: "Expenses", type: "numeric(18,2)", nullable: false, oldClrType: typeof(decimal), oldType: "numeric");
            migrationBuilder.AlterColumn<decimal>(name: "Amount", table: "CashTransactions", type: "numeric(18,2)", nullable: false, oldClrType: typeof(decimal), oldType: "numeric");

            // ── Step 5: Add new columns ──
            migrationBuilder.AddColumn<DateTime>(name: "CreatedAt", table: "Suppliers", type: "timestamp with time zone", nullable: false, defaultValue: new DateTime(1, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified));
            migrationBuilder.AddColumn<DateTime>(name: "CreatedAt", table: "PurchaseInvoices", type: "timestamp with time zone", nullable: false, defaultValue: new DateTime(1, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified));
            migrationBuilder.AddColumn<string>(name: "Notes", table: "PurchaseInvoices", type: "text", nullable: true);
            migrationBuilder.AddColumn<Guid>(name: "CashierId", table: "Invoices", type: "uuid", nullable: true);
            migrationBuilder.AddColumn<decimal>(name: "PaidAmount", table: "Invoices", type: "numeric(18,2)", nullable: false, defaultValue: 0m);
            migrationBuilder.AddColumn<decimal>(name: "RemainingAmount", table: "Invoices", type: "numeric(18,2)", nullable: false, defaultValue: 0m);
            migrationBuilder.AddColumn<decimal>(name: "SubTotal", table: "Invoices", type: "numeric(18,2)", nullable: false, defaultValue: 0m);
            migrationBuilder.AddColumn<decimal>(name: "VatAmount", table: "Invoices", type: "numeric(18,2)", nullable: false, defaultValue: 0m);
            migrationBuilder.AddColumn<decimal>(name: "VatRate", table: "Invoices", type: "numeric(5,2)", nullable: false, defaultValue: 0m);

            // ── Step 6: Recreate indexes ──
            migrationBuilder.Sql("CREATE INDEX IF NOT EXISTS \"IX_Suppliers_AccountId\" ON \"Suppliers\" (\"AccountId\");");
            migrationBuilder.Sql("CREATE INDEX IF NOT EXISTS \"IX_PurchaseInvoices_SupplierId\" ON \"PurchaseInvoices\" (\"SupplierId\");");
            migrationBuilder.Sql("CREATE INDEX IF NOT EXISTS \"IX_PurchaseInvoices_JournalEntryId\" ON \"PurchaseInvoices\" (\"JournalEntryId\");");
            migrationBuilder.Sql("CREATE INDEX IF NOT EXISTS \"IX_PurchaseInvoiceItems_PurchaseInvoiceId\" ON \"PurchaseInvoiceItems\" (\"PurchaseInvoiceId\");");
            migrationBuilder.Sql("CREATE INDEX IF NOT EXISTS \"IX_JournalEntryLines_JournalEntryId\" ON \"JournalEntryLines\" (\"JournalEntryId\");");
            migrationBuilder.Sql("CREATE INDEX IF NOT EXISTS \"IX_JournalEntryLines_AccountId\" ON \"JournalEntryLines\" (\"AccountId\");");
            migrationBuilder.Sql("CREATE INDEX IF NOT EXISTS \"IX_Expenses_JournalEntryId\" ON \"Expenses\" (\"JournalEntryId\");");
            migrationBuilder.Sql("CREATE INDEX IF NOT EXISTS \"IX_CashTransactions_TargetAccountId\" ON \"CashTransactions\" (\"TargetAccountId\");");
            migrationBuilder.Sql("CREATE INDEX IF NOT EXISTS \"IX_CashTransactions_JournalEntryId\" ON \"CashTransactions\" (\"JournalEntryId\");");
            migrationBuilder.Sql("CREATE INDEX IF NOT EXISTS \"IX_Accounts_ParentAccountId\" ON \"Accounts\" (\"ParentAccountId\");");

            // ── Step 7: Recreate FK constraints ──
            migrationBuilder.Sql("ALTER TABLE \"Accounts\" ADD CONSTRAINT \"FK_Accounts_Accounts_ParentAccountId\" FOREIGN KEY (\"ParentAccountId\") REFERENCES \"Accounts\" (\"Id\") ON DELETE RESTRICT;");
            migrationBuilder.Sql("ALTER TABLE \"Suppliers\" ADD CONSTRAINT \"FK_Suppliers_Accounts_AccountId\" FOREIGN KEY (\"AccountId\") REFERENCES \"Accounts\" (\"Id\");");
            migrationBuilder.Sql("ALTER TABLE \"PurchaseInvoices\" ADD CONSTRAINT \"FK_PurchaseInvoices_Suppliers_SupplierId\" FOREIGN KEY (\"SupplierId\") REFERENCES \"Suppliers\" (\"Id\") ON DELETE CASCADE;");
            migrationBuilder.Sql("ALTER TABLE \"PurchaseInvoices\" ADD CONSTRAINT \"FK_PurchaseInvoices_JournalEntries_JournalEntryId\" FOREIGN KEY (\"JournalEntryId\") REFERENCES \"JournalEntries\" (\"Id\");");
            migrationBuilder.Sql("ALTER TABLE \"PurchaseInvoiceItems\" ADD CONSTRAINT \"FK_PurchaseInvoiceItems_PurchaseInvoices_PurchaseInvoiceId\" FOREIGN KEY (\"PurchaseInvoiceId\") REFERENCES \"PurchaseInvoices\" (\"Id\") ON DELETE CASCADE;");
            migrationBuilder.Sql("ALTER TABLE \"JournalEntryLines\" ADD CONSTRAINT \"FK_JournalEntryLines_JournalEntries_JournalEntryId\" FOREIGN KEY (\"JournalEntryId\") REFERENCES \"JournalEntries\" (\"Id\") ON DELETE CASCADE;");
            migrationBuilder.Sql("ALTER TABLE \"JournalEntryLines\" ADD CONSTRAINT \"FK_JournalEntryLines_Accounts_AccountId\" FOREIGN KEY (\"AccountId\") REFERENCES \"Accounts\" (\"Id\") ON DELETE CASCADE;");
            migrationBuilder.Sql("ALTER TABLE \"Expenses\" ADD CONSTRAINT \"FK_Expenses_JournalEntries_JournalEntryId\" FOREIGN KEY (\"JournalEntryId\") REFERENCES \"JournalEntries\" (\"Id\");");
            migrationBuilder.Sql("ALTER TABLE \"CashTransactions\" ADD CONSTRAINT \"FK_CashTransactions_Accounts_TargetAccountId\" FOREIGN KEY (\"TargetAccountId\") REFERENCES \"Accounts\" (\"Id\");");
            migrationBuilder.Sql("ALTER TABLE \"CashTransactions\" ADD CONSTRAINT \"FK_CashTransactions_JournalEntries_JournalEntryId\" FOREIGN KEY (\"JournalEntryId\") REFERENCES \"JournalEntries\" (\"Id\");");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropColumn(
                name: "CreatedAt",
                table: "Suppliers");

            migrationBuilder.DropColumn(
                name: "CreatedAt",
                table: "PurchaseInvoices");

            migrationBuilder.DropColumn(
                name: "Notes",
                table: "PurchaseInvoices");

            migrationBuilder.DropColumn(
                name: "CashierId",
                table: "Invoices");

            migrationBuilder.DropColumn(
                name: "PaidAmount",
                table: "Invoices");

            migrationBuilder.DropColumn(
                name: "RemainingAmount",
                table: "Invoices");

            migrationBuilder.DropColumn(
                name: "SubTotal",
                table: "Invoices");

            migrationBuilder.DropColumn(
                name: "VatAmount",
                table: "Invoices");

            migrationBuilder.DropColumn(
                name: "VatRate",
                table: "Invoices");


            migrationBuilder.Sql("ALTER TABLE \"Suppliers\" ALTER COLUMN \"AccountId\" TYPE uuid USING \"AccountId\"::text::uuid;");

            migrationBuilder.Sql("ALTER TABLE \"Suppliers\" ALTER COLUMN \"Id\" TYPE uuid USING \"Id\"::text::uuid;");

            migrationBuilder.Sql("ALTER TABLE \"PurchaseInvoices\" ALTER COLUMN \"SupplierId\" TYPE uuid USING \"SupplierId\"::text::uuid;");

            migrationBuilder.Sql("ALTER TABLE \"PurchaseInvoices\" ALTER COLUMN \"JournalEntryId\" TYPE uuid USING \"JournalEntryId\"::text::uuid;");

            migrationBuilder.Sql("ALTER TABLE \"PurchaseInvoices\" ALTER COLUMN \"Id\" DROP IDENTITY IF EXISTS;");
            migrationBuilder.Sql("ALTER TABLE \"PurchaseInvoices\" ALTER COLUMN \"Id\" TYPE uuid USING \"Id\"::text::uuid;");

            migrationBuilder.Sql("ALTER TABLE \"PurchaseInvoiceItems\" ALTER COLUMN \"PurchaseInvoiceId\" TYPE uuid USING \"PurchaseInvoiceId\"::text::uuid;");

            migrationBuilder.Sql("ALTER TABLE \"PurchaseInvoiceItems\" ALTER COLUMN \"Id\" DROP IDENTITY IF EXISTS;");
            migrationBuilder.Sql("ALTER TABLE \"PurchaseInvoiceItems\" ALTER COLUMN \"Id\" TYPE uuid USING \"Id\"::text::uuid;");

            migrationBuilder.Sql("ALTER TABLE \"JournalEntryLines\" ALTER COLUMN \"JournalEntryId\" TYPE uuid USING \"JournalEntryId\"::text::uuid;");

            migrationBuilder.Sql("ALTER TABLE \"JournalEntryLines\" ALTER COLUMN \"AccountId\" TYPE uuid USING \"AccountId\"::text::uuid;");

            migrationBuilder.Sql("ALTER TABLE \"JournalEntryLines\" ALTER COLUMN \"Id\" DROP IDENTITY IF EXISTS;");
            migrationBuilder.Sql("ALTER TABLE \"JournalEntryLines\" ALTER COLUMN \"Id\" TYPE uuid USING \"Id\"::text::uuid;");

            migrationBuilder.Sql("ALTER TABLE \"JournalEntries\" ALTER COLUMN \"Id\" TYPE uuid USING \"Id\"::text::uuid;");

            migrationBuilder.Sql("ALTER TABLE \"Expenses\" ALTER COLUMN \"JournalEntryId\" TYPE uuid USING \"JournalEntryId\"::text::uuid;");

            migrationBuilder.Sql("ALTER TABLE \"Expenses\" ALTER COLUMN \"Id\" DROP IDENTITY IF EXISTS;");
            migrationBuilder.Sql("ALTER TABLE \"Expenses\" ALTER COLUMN \"Id\" TYPE uuid USING \"Id\"::text::uuid;");

            migrationBuilder.Sql("ALTER TABLE \"CashTransactions\" ALTER COLUMN \"TargetAccountId\" TYPE uuid USING \"TargetAccountId\"::text::uuid;");

            migrationBuilder.Sql("ALTER TABLE \"CashTransactions\" ALTER COLUMN \"JournalEntryId\" TYPE uuid USING \"JournalEntryId\"::text::uuid;");

            migrationBuilder.Sql("ALTER TABLE \"CashTransactions\" ALTER COLUMN \"Id\" DROP IDENTITY IF EXISTS;");
            migrationBuilder.Sql("ALTER TABLE \"CashTransactions\" ALTER COLUMN \"Id\" TYPE uuid USING \"Id\"::text::uuid;");

            migrationBuilder.Sql("ALTER TABLE \"Accounts\" ALTER COLUMN \"ParentAccountId\" TYPE uuid USING \"ParentAccountId\"::text::uuid;");

            migrationBuilder.Sql("ALTER TABLE \"Accounts\" ALTER COLUMN \"Id\" TYPE uuid USING \"Id\"::text::uuid;");

            migrationBuilder.AlterColumn<decimal>(
                name: "OpeningBalance",
                table: "Suppliers",
                type: "numeric",
                nullable: false,
                oldClrType: typeof(decimal),
                oldType: "numeric(18,2)");

            migrationBuilder.AlterColumn<int>(
                name: "AccountId",
                table: "Suppliers",
                type: "integer",
                nullable: true,
                oldClrType: typeof(Guid),
                oldType: "uuid",
                oldNullable: true);

            migrationBuilder.AlterColumn<int>(
                name: "Id",
                table: "Suppliers",
                type: "integer",
                nullable: false,
                oldClrType: typeof(Guid),
                oldType: "uuid")
                .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn);

            migrationBuilder.AlterColumn<decimal>(
                name: "TotalAmount",
                table: "PurchaseInvoices",
                type: "numeric",
                nullable: false,
                oldClrType: typeof(decimal),
                oldType: "numeric(18,2)");

            migrationBuilder.AlterColumn<int>(
                name: "SupplierId",
                table: "PurchaseInvoices",
                type: "integer",
                nullable: false,
                oldClrType: typeof(Guid),
                oldType: "uuid");

            migrationBuilder.AlterColumn<decimal>(
                name: "RemainingAmount",
                table: "PurchaseInvoices",
                type: "numeric",
                nullable: false,
                oldClrType: typeof(decimal),
                oldType: "numeric(18,2)");

            migrationBuilder.AlterColumn<decimal>(
                name: "PaidAmount",
                table: "PurchaseInvoices",
                type: "numeric",
                nullable: false,
                oldClrType: typeof(decimal),
                oldType: "numeric(18,2)");

            migrationBuilder.AlterColumn<decimal>(
                name: "NetAmount",
                table: "PurchaseInvoices",
                type: "numeric",
                nullable: false,
                oldClrType: typeof(decimal),
                oldType: "numeric(18,2)");

            migrationBuilder.AlterColumn<int>(
                name: "JournalEntryId",
                table: "PurchaseInvoices",
                type: "integer",
                nullable: true,
                oldClrType: typeof(Guid),
                oldType: "uuid",
                oldNullable: true);

            migrationBuilder.AlterColumn<decimal>(
                name: "Discount",
                table: "PurchaseInvoices",
                type: "numeric",
                nullable: false,
                oldClrType: typeof(decimal),
                oldType: "numeric(18,2)");

            migrationBuilder.AlterColumn<int>(
                name: "Id",
                table: "PurchaseInvoices",
                type: "integer",
                nullable: false,
                oldClrType: typeof(Guid),
                oldType: "uuid")
                .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn);

            migrationBuilder.AlterColumn<decimal>(
                name: "UnitPrice",
                table: "PurchaseInvoiceItems",
                type: "numeric",
                nullable: false,
                oldClrType: typeof(decimal),
                oldType: "numeric(18,2)");

            migrationBuilder.AlterColumn<decimal>(
                name: "TotalPrice",
                table: "PurchaseInvoiceItems",
                type: "numeric",
                nullable: false,
                oldClrType: typeof(decimal),
                oldType: "numeric(18,2)");

            migrationBuilder.AlterColumn<int>(
                name: "PurchaseInvoiceId",
                table: "PurchaseInvoiceItems",
                type: "integer",
                nullable: false,
                oldClrType: typeof(Guid),
                oldType: "uuid");

            migrationBuilder.AlterColumn<int>(
                name: "Id",
                table: "PurchaseInvoiceItems",
                type: "integer",
                nullable: false,
                oldClrType: typeof(Guid),
                oldType: "uuid")
                .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn);

            migrationBuilder.AlterColumn<int>(
                name: "JournalEntryId",
                table: "JournalEntryLines",
                type: "integer",
                nullable: false,
                oldClrType: typeof(Guid),
                oldType: "uuid");

            migrationBuilder.AlterColumn<decimal>(
                name: "Debit",
                table: "JournalEntryLines",
                type: "numeric",
                nullable: false,
                oldClrType: typeof(decimal),
                oldType: "numeric(18,2)");

            migrationBuilder.AlterColumn<decimal>(
                name: "Credit",
                table: "JournalEntryLines",
                type: "numeric",
                nullable: false,
                oldClrType: typeof(decimal),
                oldType: "numeric(18,2)");

            migrationBuilder.AlterColumn<int>(
                name: "AccountId",
                table: "JournalEntryLines",
                type: "integer",
                nullable: false,
                oldClrType: typeof(Guid),
                oldType: "uuid");

            migrationBuilder.AlterColumn<int>(
                name: "Id",
                table: "JournalEntryLines",
                type: "integer",
                nullable: false,
                oldClrType: typeof(Guid),
                oldType: "uuid")
                .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn);

            migrationBuilder.AlterColumn<int>(
                name: "Id",
                table: "JournalEntries",
                type: "integer",
                nullable: false,
                oldClrType: typeof(Guid),
                oldType: "uuid")
                .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn);

            migrationBuilder.AlterColumn<decimal>(
                name: "DiscountAmount",
                table: "Invoices",
                type: "numeric",
                nullable: false,
                oldClrType: typeof(decimal),
                oldType: "numeric(18,2)");

            migrationBuilder.AlterColumn<int>(
                name: "JournalEntryId",
                table: "Expenses",
                type: "integer",
                nullable: true,
                oldClrType: typeof(Guid),
                oldType: "uuid",
                oldNullable: true);

            migrationBuilder.AlterColumn<decimal>(
                name: "Amount",
                table: "Expenses",
                type: "numeric",
                nullable: false,
                oldClrType: typeof(decimal),
                oldType: "numeric(18,2)");

            migrationBuilder.AlterColumn<int>(
                name: "Id",
                table: "Expenses",
                type: "integer",
                nullable: false,
                oldClrType: typeof(Guid),
                oldType: "uuid")
                .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn);

            migrationBuilder.AlterColumn<int>(
                name: "TargetAccountId",
                table: "CashTransactions",
                type: "integer",
                nullable: true,
                oldClrType: typeof(Guid),
                oldType: "uuid",
                oldNullable: true);

            migrationBuilder.AlterColumn<int>(
                name: "JournalEntryId",
                table: "CashTransactions",
                type: "integer",
                nullable: true,
                oldClrType: typeof(Guid),
                oldType: "uuid",
                oldNullable: true);

            migrationBuilder.AlterColumn<decimal>(
                name: "Amount",
                table: "CashTransactions",
                type: "numeric",
                nullable: false,
                oldClrType: typeof(decimal),
                oldType: "numeric(18,2)");

            migrationBuilder.AlterColumn<int>(
                name: "Id",
                table: "CashTransactions",
                type: "integer",
                nullable: false,
                oldClrType: typeof(Guid),
                oldType: "uuid")
                .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn);

            migrationBuilder.AlterColumn<int>(
                name: "ParentAccountId",
                table: "Accounts",
                type: "integer",
                nullable: true,
                oldClrType: typeof(Guid),
                oldType: "uuid",
                oldNullable: true);

            migrationBuilder.AlterColumn<int>(
                name: "Id",
                table: "Accounts",
                type: "integer",
                nullable: false,
                oldClrType: typeof(Guid),
                oldType: "uuid")
                .Annotation("Npgsql:ValueGenerationStrategy", NpgsqlValueGenerationStrategy.IdentityByDefaultColumn);
        }
    }
}
