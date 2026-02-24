using ALIkhlasPOS.Domain.Entities;
using Microsoft.EntityFrameworkCore;

namespace ALIkhlasPOS.Infrastructure.Data;

public class ApplicationDbContext : DbContext
{
    public ApplicationDbContext(DbContextOptions<ApplicationDbContext> options) : base(options)
    {
    }

    // ===== Core POS Entities =====
    public DbSet<User> Users { get; set; } = null!;
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
    public DbSet<Expense> Expenses { get; set; }
    public DbSet<CashTransaction> CashTransactions { get; set; } = null!;

    // ===== Suppliers & Purchasing =====
    public DbSet<Supplier> Suppliers { get; set; }
    public DbSet<PurchaseInvoice> PurchaseInvoices { get; set; }
    public DbSet<PurchaseInvoiceItem> PurchaseInvoiceItems { get; set; }

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


        // --- Product ---
        modelBuilder.Entity<Product>()
            .HasIndex(p => p.GlobalBarcode)
            .IsUnique();
        modelBuilder.Entity<Product>().Property(p => p.Price).HasColumnType("numeric(18,2)");
        modelBuilder.Entity<Product>().Property(p => p.PurchasePrice).HasColumnType("numeric(18,2)");
        modelBuilder.Entity<Product>().Property(p => p.WholesalePrice).HasColumnType("numeric(18,2)");

        // --- Bundle ---
        modelBuilder.Entity<Bundle>()
            .HasOne(b => b.ParentProduct).WithMany()
            .HasForeignKey(b => b.ParentProductId).OnDelete(DeleteBehavior.Restrict);
        modelBuilder.Entity<Bundle>()
            .HasOne(b => b.SubProduct).WithMany()
            .HasForeignKey(b => b.SubProductId).OnDelete(DeleteBehavior.Restrict);
        modelBuilder.Entity<Bundle>().Property(b => b.DiscountAmount).HasColumnType("numeric(18,2)");

        // --- ProductUnit ---
        modelBuilder.Entity<ProductUnit>()
            .HasOne(u => u.Product).WithMany()
            .HasForeignKey(u => u.ProductId).OnDelete(DeleteBehavior.Cascade);
        modelBuilder.Entity<ProductUnit>().Property(u => u.UnitPrice).HasColumnType("numeric(18,2)");

        // --- Invoice (updated with new financial fields) ---
        modelBuilder.Entity<Invoice>().Property(i => i.SubTotal).HasColumnType("numeric(18,2)");
        modelBuilder.Entity<Invoice>().Property(i => i.TotalAmount).HasColumnType("numeric(18,2)");
        modelBuilder.Entity<Invoice>().Property(i => i.DiscountAmount).HasColumnType("numeric(18,2)");
        modelBuilder.Entity<Invoice>().Property(i => i.VatRate).HasColumnType("numeric(5,2)");
        modelBuilder.Entity<Invoice>().Property(i => i.VatAmount).HasColumnType("numeric(18,2)");
        modelBuilder.Entity<Invoice>().Property(i => i.PaidAmount).HasColumnType("numeric(18,2)");
        modelBuilder.Entity<Invoice>().Property(i => i.RemainingAmount).HasColumnType("numeric(18,2)");
        modelBuilder.Entity<InvoiceItem>().Property(i => i.UnitPrice).HasColumnType("numeric(18,2)");
        modelBuilder.Entity<Invoice>()
            .HasOne(i => i.Customer)
            .WithMany(c => c.Invoices)
            .HasForeignKey(i => i.CustomerId)
            .OnDelete(DeleteBehavior.SetNull);

        // --- Return Invoice ---
        modelBuilder.Entity<ReturnInvoice>()
            .HasOne(r => r.OriginalInvoice).WithMany()
            .HasForeignKey(r => r.OriginalInvoiceId).OnDelete(DeleteBehavior.Restrict);
        modelBuilder.Entity<ReturnInvoice>().Property(r => r.RefundAmount).HasColumnType("numeric(18,2)");
        modelBuilder.Entity<ReturnInvoiceItem>()
            .HasOne(ri => ri.Product).WithMany()
            .HasForeignKey(ri => ri.ProductId).OnDelete(DeleteBehavior.Restrict);
        modelBuilder.Entity<ReturnInvoiceItem>().Property(ri => ri.UnitPrice).HasColumnType("numeric(18,2)");

        // --- Installment ---
        modelBuilder.Entity<Installment>().Property(i => i.Amount).HasColumnType("numeric(18,2)");

        // --- Customer ---
        modelBuilder.Entity<Customer>().Property(c => c.TotalPurchases).HasColumnType("numeric(18,2)");
        modelBuilder.Entity<Customer>().Property(c => c.TotalPaid).HasColumnType("numeric(18,2)");

        // --- ERP Accounting ---
        modelBuilder.Entity<JournalEntryLine>().Property(l => l.Debit).HasColumnType("numeric(18,2)");
        modelBuilder.Entity<JournalEntryLine>().Property(l => l.Credit).HasColumnType("numeric(18,2)");
        modelBuilder.Entity<CashTransaction>().Property(t => t.Amount).HasColumnType("numeric(18,2)");
        modelBuilder.Entity<Expense>().Property(e => e.Amount).HasColumnType("numeric(18,2)");
        modelBuilder.Entity<Supplier>().Property(s => s.OpeningBalance).HasColumnType("numeric(18,2)");
        modelBuilder.Entity<PurchaseInvoice>().Property(p => p.TotalAmount).HasColumnType("numeric(18,2)");
        modelBuilder.Entity<PurchaseInvoice>().Property(p => p.Discount).HasColumnType("numeric(18,2)");
        modelBuilder.Entity<PurchaseInvoice>().Property(p => p.NetAmount).HasColumnType("numeric(18,2)");
        modelBuilder.Entity<PurchaseInvoice>().Property(p => p.PaidAmount).HasColumnType("numeric(18,2)");
        modelBuilder.Entity<PurchaseInvoice>().Property(p => p.RemainingAmount).HasColumnType("numeric(18,2)");
        modelBuilder.Entity<PurchaseInvoiceItem>().Property(p => p.UnitPrice).HasColumnType("numeric(18,2)");
        modelBuilder.Entity<PurchaseInvoiceItem>().Property(p => p.TotalPrice).HasColumnType("numeric(18,2)");

        // --- Shop Settings ---
        modelBuilder.Entity<ShopSettings>().Property(s => s.DefaultVatRate).HasColumnType("numeric(5,2)");
    }
}
