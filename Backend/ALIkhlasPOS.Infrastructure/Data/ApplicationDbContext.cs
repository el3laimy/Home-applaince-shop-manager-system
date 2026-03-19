using ALIkhlasPOS.Domain.Entities;
using Microsoft.EntityFrameworkCore;
using System.Text.Json;

namespace ALIkhlasPOS.Infrastructure.Data;

public class ApplicationDbContext : DbContext
{
    public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options) : base(options)
    {
    }

    // ===== Core POS Entities =====
    public DbSet<User> Users { get; set; } = null!;
    public DbSet<RefreshToken> RefreshTokens { get; set; } = null!;
    public DbSet<Product> Products { get; set; } = null!;
    public DbSet<Bundle> Bundles { get; set; }
    public DbSet<ProductUnit> ProductUnits { get; set; }
    public DbSet<Invoice> Invoices { get; set; }
    public DbSet<InvoiceItem> InvoiceItems { get; set; }
    public DbSet<ReturnInvoice> ReturnInvoices { get; set; }
    public DbSet<ReturnInvoiceItem> ReturnInvoiceItems { get; set; }

    // ===== Customers =====
    public DbSet<Customer> Customers { get; set; }

    // ===== Bridal & Installments =====
    public DbSet<Installment> Installments { get; set; }

    // ===== ERP Accounting =====
    public DbSet<Account> Accounts { get; set; }
    public DbSet<JournalEntry> JournalEntries { get; set; }
    public DbSet<JournalEntryLine> JournalEntryLines { get; set; }
    public DbSet<ExpenseCategory> ExpenseCategories { get; set; }
    public DbSet<Expense> Expenses { get; set; }
    public DbSet<CashTransaction> CashTransactions { get; set; } = null!;

    // ===== Suppliers & Purchasing =====
    public DbSet<Supplier> Suppliers { get; set; }
    public DbSet<PurchaseInvoice> PurchaseInvoices { get; set; }
    public DbSet<PurchaseInvoiceItem> PurchaseInvoiceItems { get; set; }

    // ERP - Inventory / Stock
    public DbSet<StockAdjustment> StockAdjustments { get; set; }
    public DbSet<StockMovement> StockMovements { get; set; }

    // ===== Audit Trail =====
    public DbSet<AuditLog> AuditLogs { get; set; }

    // ===== Shop Configuration =====
    public DbSet<ShopSettings> ShopSettings { get; set; } = null!;

    // ===== Shift & Z-Report =====
    public DbSet<Shift> Shifts { get; set; } = null!;

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);
        
        // Shift -> Cashier (User) Relation
        modelBuilder.Entity<Shift>()
            .HasOne(s => s.Cashier)
            .WithMany()
            .HasForeignKey(s => s.CashierId)
            .OnDelete(DeleteBehavior.Restrict);

        // Expense -> ExpenseCategory Relation
        modelBuilder.Entity<Expense>()
            .HasOne(e => e.Category)
            .WithMany()
            .HasForeignKey(e => e.CategoryId)
            .OnDelete(DeleteBehavior.Restrict);

        // Seed default expense categories
        modelBuilder.Entity<ExpenseCategory>().HasData(
            new ExpenseCategory { Id = Guid.Parse("11111111-1111-1111-1111-111111111111"), Name = "مصروفات تشغيل (كهرباء، غاز، إلخ)" },
            new ExpenseCategory { Id = Guid.Parse("22222222-2222-2222-2222-222222222222"), Name = "رواتب وأجور" },
            new ExpenseCategory { Id = Guid.Parse("33333333-3333-3333-3333-333333333333"), Name = "تسويق وإعلانات" },
            new ExpenseCategory { Id = Guid.Parse("44444444-4444-4444-4444-444444444444"), Name = "أخرى" }
        );


        // --- Product ---
        modelBuilder.Entity<Product>().HasQueryFilter(p => p.IsActive);
        modelBuilder.Entity<Product>()
            .HasIndex(p => p.GlobalBarcode)
            .IsUnique()
            .HasFilter("\"GlobalBarcode\" IS NOT NULL");
        modelBuilder.Entity<Product>().Property(p => p.Price).HasColumnType("numeric(18,4)");
        modelBuilder.Entity<Product>().Property(p => p.PurchasePrice).HasColumnType("numeric(18,4)");
        modelBuilder.Entity<Product>().Property(p => p.WholesalePrice).HasColumnType("numeric(18,4)");

        // --- Bundle ---
        modelBuilder.Entity<Bundle>()
            .HasOne(b => b.ParentProduct).WithMany()
            .HasForeignKey(b => b.ParentProductId).OnDelete(DeleteBehavior.Restrict);
        modelBuilder.Entity<Bundle>()
            .HasOne(b => b.SubProduct).WithMany()
            .HasForeignKey(b => b.SubProductId).OnDelete(DeleteBehavior.Restrict);
        modelBuilder.Entity<Bundle>().Property(b => b.DiscountAmount).HasColumnType("numeric(18,4)");

        // --- ProductUnit ---
        modelBuilder.Entity<ProductUnit>()
            .HasOne(u => u.Product).WithMany()
            .HasForeignKey(u => u.ProductId).OnDelete(DeleteBehavior.Cascade);
        modelBuilder.Entity<ProductUnit>().Property(u => u.UnitPrice).HasColumnType("numeric(18,4)");

        // --- Invoice (updated with new financial fields) ---
        modelBuilder.Entity<Invoice>().Property(i => i.SubTotal).HasColumnType("numeric(18,4)");
        modelBuilder.Entity<Invoice>().Property(i => i.TotalAmount).HasColumnType("numeric(18,4)");
        modelBuilder.Entity<Invoice>().Property(i => i.DiscountAmount).HasColumnType("numeric(18,4)");
        modelBuilder.Entity<Invoice>().Property(i => i.VatRate).HasColumnType("numeric(5,4)");
        modelBuilder.Entity<Invoice>().Property(i => i.VatAmount).HasColumnType("numeric(18,4)");
        modelBuilder.Entity<Invoice>().Property(i => i.PaidAmount).HasColumnType("numeric(18,4)");
        modelBuilder.Entity<Invoice>().Property(i => i.RemainingAmount).HasColumnType("numeric(18,4)");
        modelBuilder.Entity<InvoiceItem>().Property(i => i.UnitPrice).HasColumnType("numeric(18,4)");
        modelBuilder.Entity<Invoice>()
            .HasOne(i => i.Customer)
            .WithMany(c => c.Invoices)
            .HasForeignKey(i => i.CustomerId)
            .OnDelete(DeleteBehavior.Restrict);

        // --- Return Invoice ---
        modelBuilder.Entity<ReturnInvoice>()
            .HasOne(r => r.OriginalInvoice).WithMany()
            .HasForeignKey(r => r.OriginalInvoiceId).OnDelete(DeleteBehavior.Restrict);
        modelBuilder.Entity<ReturnInvoice>().Property(r => r.RefundAmount).HasColumnType("numeric(18,4)");
        modelBuilder.Entity<ReturnInvoiceItem>()
            .HasOne(ri => ri.Product).WithMany()
            .HasForeignKey(ri => ri.ProductId).OnDelete(DeleteBehavior.Restrict);
        modelBuilder.Entity<ReturnInvoiceItem>().Property(ri => ri.UnitPrice).HasColumnType("numeric(18,4)");

        // --- Installment ---
        modelBuilder.Entity<Installment>().Property(i => i.Amount).HasColumnType("numeric(18,4)");

        // --- Customer ---
        modelBuilder.Entity<Customer>().HasQueryFilter(c => c.IsActive);
        modelBuilder.Entity<Customer>().Property(c => c.TotalPurchases).HasColumnType("numeric(18,4)");
        modelBuilder.Entity<Customer>().Property(c => c.TotalPaid).HasColumnType("numeric(18,4)");

        // --- ERP Accounting ---
        modelBuilder.Entity<JournalEntryLine>().Property(l => l.Debit).HasColumnType("numeric(18,4)");
        modelBuilder.Entity<JournalEntryLine>().Property(l => l.Credit).HasColumnType("numeric(18,4)");
        modelBuilder.Entity<CashTransaction>().Property(t => t.Amount).HasColumnType("numeric(18,4)");
        modelBuilder.Entity<Expense>().Property(e => e.Amount).HasColumnType("numeric(18,4)");
        modelBuilder.Entity<Supplier>().Property(s => s.OpeningBalance).HasColumnType("numeric(18,4)");
        modelBuilder.Entity<PurchaseInvoice>().Property(p => p.TotalAmount).HasColumnType("numeric(18,4)");
        modelBuilder.Entity<PurchaseInvoice>().Property(p => p.Discount).HasColumnType("numeric(18,4)");
        modelBuilder.Entity<PurchaseInvoice>().Property(p => p.NetAmount).HasColumnType("numeric(18,4)");
        modelBuilder.Entity<PurchaseInvoice>().Property(p => p.PaidAmount).HasColumnType("numeric(18,4)");
        modelBuilder.Entity<PurchaseInvoice>().Property(p => p.RemainingAmount).HasColumnType("numeric(18,4)");
        modelBuilder.Entity<PurchaseInvoiceItem>().Property(p => p.UnitPrice).HasColumnType("numeric(18,4)");
        modelBuilder.Entity<PurchaseInvoiceItem>().Property(p => p.TotalPrice).HasColumnType("numeric(18,4)");

        // --- Shop Settings ---
        modelBuilder.Entity<ShopSettings>().Property(s => s.DefaultVatRate).HasColumnType("numeric(5,4)");

        // --- Performance & Sequences ---
        modelBuilder.HasSequence<long>("invoice_seq")
            .StartsAt(1)
            .IncrementsBy(1);
            
        modelBuilder.HasSequence<long>("internal_barcode_seq")
            .StartsAt(1)
            .IncrementsBy(1);
            
        modelBuilder.HasSequence<long>("voucher_seq")
            .StartsAt(1)
            .IncrementsBy(1);

        modelBuilder.Entity<Invoice>()
            .HasIndex(i => i.InvoiceNo)
            .IsUnique();
    }

    public override async Task<int> SaveChangesAsync(CancellationToken cancellationToken = default)
    {
        var auditEntries = new List<AuditLog>();
        
        var entries = ChangeTracker.Entries()
            .Where(e => e.Entity is not AuditLog && 
                       (e.State == EntityState.Added || e.State == EntityState.Modified || e.State == EntityState.Deleted))
            .ToList();

        foreach (var entry in entries)
        {
            var auditLog = new AuditLog
            {
                TableName = entry.Metadata.GetTableName() ?? entry.Metadata.Name,
                Action = entry.State.ToString()
            };

            var primaryKey = entry.Properties.FirstOrDefault(p => p.Metadata.IsPrimaryKey());
            auditLog.RecordId = primaryKey?.CurrentValue?.ToString() ?? Guid.NewGuid().ToString();

            var createdByProp = entry.Properties.FirstOrDefault(p => p.Metadata.Name == "CreatedBy" || p.Metadata.Name == "UpdatedBy");
            if (createdByProp != null && createdByProp.CurrentValue != null)
            {
                auditLog.CreatedBy = createdByProp.CurrentValue.ToString() ?? "System";
            }

            if (entry.State == EntityState.Added)
            {
                var newValues = new Dictionary<string, object?>();
                foreach (var prop in entry.Properties)
                {
                    newValues[prop.Metadata.Name] = prop.CurrentValue;
                }
                auditLog.NewValues = JsonSerializer.Serialize(newValues);
            }
            else if (entry.State == EntityState.Modified)
            {
                var oldValues = new Dictionary<string, object?>();
                var newValues = new Dictionary<string, object?>();
                
                foreach (var prop in entry.Properties.Where(p => p.IsModified))
                {
                    oldValues[prop.Metadata.Name] = prop.OriginalValue;
                    newValues[prop.Metadata.Name] = prop.CurrentValue;
                }
                auditLog.OldValues = JsonSerializer.Serialize(oldValues);
                auditLog.NewValues = JsonSerializer.Serialize(newValues);
            }
            else if (entry.State == EntityState.Deleted)
            {
                var oldValues = new Dictionary<string, object?>();
                foreach (var prop in entry.Properties)
                {
                    oldValues[prop.Metadata.Name] = prop.OriginalValue;
                }
                auditLog.OldValues = JsonSerializer.Serialize(oldValues);
            }

            auditEntries.Add(auditLog);
        }

        if (auditEntries.Any())
        {
            AuditLogs.AddRange(auditEntries);
        }

        return await base.SaveChangesAsync(cancellationToken);
    }
}
