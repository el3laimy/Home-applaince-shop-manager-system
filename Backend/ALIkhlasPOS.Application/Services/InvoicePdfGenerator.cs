using ALIkhlasPOS.Domain.Entities;
using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;

namespace ALIkhlasPOS.Application.Services;

public class InvoicePdfGenerator
{
    public InvoicePdfGenerator()
    {
        // QuestPDF requires setting the license type
        QuestPDF.Settings.License = LicenseType.Community;
    }

    public byte[] GenerateInvoicePdf(Invoice invoice)
    {
        var document = Document.Create(container =>
        {
            container.Page(page =>
            {
                page.Size(PageSizes.A5);
                page.Margin(1, Unit.Centimetre);
                page.PageColor(Colors.White);
                page.DefaultTextStyle(x => x.FontSize(11).FontFamily(Fonts.Arial));
                
                // Enable RTL for Arabic
                page.ContentFromRightToLeft();

                page.Header().Element(c => ComposeHeader(c, invoice));
                page.Content().Element(c => ComposeContent(c, invoice));
                page.Footer().Element(ComposeFooter);
            });
        });

        return document.GeneratePdf();
    }

    private void ComposeHeader(IContainer container, Invoice invoice)
    {
        var titleStyle = TextStyle.Default.FontSize(20).SemiBold().FontColor(Colors.Blue.Darken2);

        container.Row(row =>
        {
            row.RelativeItem().Column(column =>
            {
                column.Item().Text("إخلاص للأجهزة المنزلية").Style(titleStyle);

                column.Item().Text(text =>
                {
                    text.Span("رقم الفاتورة: ").SemiBold();
                    text.Span(invoice.InvoiceNo);
                });

                column.Item().Text(text =>
                {
                    text.Span("تاريخ الفاتورة: ").SemiBold();
                    text.Span(invoice.CreatedAt.ToString("d MMMM yyyy, hh:mm tt"));
                });
                
                if (invoice.Customer != null)
                {
                    column.Item().PaddingTop(5).Text(text =>
                    {
                        text.Span("العميل: ").SemiBold();
                        text.Span(invoice.Customer.Name);
                    });
                }
                
                column.Item().Text(text =>
                {
                    text.Span("الكاشير: ").SemiBold();
                    text.Span(invoice.CreatedBy);
                });
            });
        });
    }

    private void ComposeContent(IContainer container, Invoice invoice)
    {
        container.PaddingVertical(1, Unit.Centimetre).Column(column =>
        {
            column.Spacing(5);

            column.Item().Element(c => ComposeTable(c, invoice));

            var totalPrice = invoice.TotalAmount;
            
            column.Item().PaddingTop(15).AlignRight().Text($"المجموع: {totalPrice:N2} ج.م").SemiBold().FontSize(14);
            
            if (invoice.DiscountAmount > 0)
                column.Item().AlignRight().Text($"الخصم: {invoice.DiscountAmount:N2} ج.م").FontColor(Colors.Red.Medium);

            if (invoice.VatAmount > 0)
                column.Item().AlignRight().Text($"الضريبة: {invoice.VatAmount:N2} ج.م");
                
            column.Item().AlignRight().Text($"المدفوع: {invoice.PaidAmount:N2} ج.م");
            column.Item().AlignRight().Text($"المتبقي: {invoice.RemainingAmount:N2} ج.م").SemiBold();
            
            if (!string.IsNullOrEmpty(invoice.Notes))
            {
                column.Item().PaddingTop(15).Text(text =>
                {
                    text.Span("ملاحظات: ").SemiBold();
                    text.Span(invoice.Notes);
                });
            }
        });
    }

    private void ComposeTable(IContainer container, Invoice invoice)
    {
        container.Table(table =>
        {
            // step 1
            table.ColumnsDefinition(columns =>
            {
                columns.ConstantColumn(30);
                columns.RelativeColumn();
                columns.ConstantColumn(80);
                columns.ConstantColumn(50);
                columns.ConstantColumn(80);
            });

            // step 2
            table.Header(header =>
            {
                header.Cell().Element(CellStyle).Text("#");
                header.Cell().Element(CellStyle).Text("الصنف");
                header.Cell().Element(CellStyle).AlignRight().Text("سعر الوحدة");
                header.Cell().Element(CellStyle).AlignRight().Text("الكمية");
                header.Cell().Element(CellStyle).AlignRight().Text("الإجمالي");

                static IContainer CellStyle(IContainer container)
                {
                    return container.DefaultTextStyle(x => x.SemiBold()).PaddingVertical(5).BorderBottom(1).BorderColor(Colors.Black);
                }
            });

            // step 3
            var index = 1;
            foreach (var item in invoice.Items)
            {
                table.Cell().Element(CellStyle).Text(index.ToString());
                table.Cell().Element(CellStyle).Text(item.Product.Name);
                table.Cell().Element(CellStyle).AlignRight().Text($"{item.UnitPrice:N2} ج.م");
                table.Cell().Element(CellStyle).AlignRight().Text(item.Quantity.ToString());
                table.Cell().Element(CellStyle).AlignRight().Text($"{item.TotalPrice:N2} ج.م");

                index++;
            }

            static IContainer CellStyle(IContainer container)
            {
                return container.BorderBottom(1).BorderColor(Colors.Grey.Lighten2).PaddingVertical(5);
            }
        });
    }

    private void ComposeFooter(IContainer container)
    {
        container.AlignCenter().Text(x =>
        {
            x.Span("شكراً لتسوقكم من إخلاص للأجهزة المنزلية").SemiBold();
        });
    }

    public byte[] GenerateCustomerStatementPdf(Customer customer, List<dynamic> timelineItems)
    {
        var document = Document.Create(container =>
        {
            container.Page(page =>
            {
                page.Size(PageSizes.A4);
                page.Margin(1, Unit.Centimetre);
                page.PageColor(Colors.White);
                page.DefaultTextStyle(x => x.FontSize(11).FontFamily(Fonts.Arial));
                
                page.ContentFromRightToLeft();

                page.Header().Element(c => ComposeStatementHeader(c, customer));
                page.Content().Element(c => ComposeStatementContent(c, customer, timelineItems));
                page.Footer().Element(ComposeFooter);
            });
        });

        return document.GeneratePdf();
    }

    private void ComposeStatementHeader(IContainer container, Customer customer)
    {
        var titleStyle = TextStyle.Default.FontSize(20).SemiBold().FontColor(Colors.Blue.Darken2);

        container.Row(row =>
        {
            row.RelativeItem().Column(column =>
            {
                column.Item().Text("إخلاص للأجهزة المنزلية").Style(titleStyle);
                column.Item().PaddingTop(5).Text("كشف حساب عميل").FontSize(16).SemiBold();
                column.Item().PaddingTop(10).Text(text =>
                {
                    text.Span("اسم العميل: ").SemiBold();
                    text.Span(customer.Name);
                });
                if (!string.IsNullOrEmpty(customer.Phone))
                {
                    column.Item().Text(text =>
                    {
                        text.Span("رقم الهاتف: ").SemiBold();
                        text.Span(customer.Phone);
                    });
                }
                column.Item().Text(text =>
                {
                    text.Span("تاريخ الإصدار: ").SemiBold();
                    text.Span(DateTime.UtcNow.ToString("d MMMM yyyy, hh:mm tt"));
                });
            });
        });
    }

    private void ComposeStatementContent(IContainer container, Customer customer, List<dynamic> timelineItems)
    {
        container.PaddingVertical(1, Unit.Centimetre).Column(column =>
        {
            column.Spacing(5);
            
            // Summary Block
            column.Item().Border(1).BorderColor(Colors.Grey.Lighten1).Padding(10).Row(row => 
            {
                row.RelativeItem().Column(c => {
                    c.Item().Text("إجمالي المشتريات").FontSize(10).FontColor(Colors.Grey.Darken2);
                    c.Item().Text($"{customer.TotalPurchases:N2} ج.م").SemiBold().FontSize(14);
                });
                row.RelativeItem().Column(c => {
                    c.Item().Text("إجمالي المدفوعات").FontSize(10).FontColor(Colors.Grey.Darken2);
                    c.Item().Text($"{customer.TotalPaid:N2} ج.م").SemiBold().FontSize(14).FontColor(Colors.Green.Darken2);
                });
                row.RelativeItem().Column(c => {
                    c.Item().Text("الرصيد المستحق").FontSize(10).FontColor(Colors.Grey.Darken2);
                    c.Item().Text($"{customer.Balance:N2} ج.م").SemiBold().FontSize(14).FontColor(customer.Balance > 0 ? Colors.Red.Darken2 : Colors.Green.Darken2);
                });
            });

            column.Item().PaddingTop(20).Text("السجل الزمني للحركات المالية").FontSize(14).SemiBold().Underline();
            
            column.Item().PaddingTop(10).Table(table =>
            {
                table.ColumnsDefinition(columns =>
                {
                    columns.ConstantColumn(80); // Date
                    columns.RelativeColumn();   // Type & Ref
                    columns.ConstantColumn(80); // Total
                    columns.ConstantColumn(80); // Paid
                    columns.ConstantColumn(80); // Remaining
                });

                table.Header(header =>
                {
                    header.Cell().Element(HeaderStyle).Text("التاريخ");
                    header.Cell().Element(HeaderStyle).Text("البيان");
                    header.Cell().Element(HeaderStyle).AlignRight().Text("الإجمالي");
                    header.Cell().Element(HeaderStyle).AlignRight().Text("المدفوع");
                    header.Cell().Element(HeaderStyle).AlignRight().Text("المتبقي");

                    static IContainer HeaderStyle(IContainer c) => c.DefaultTextStyle(x => x.SemiBold()).PaddingVertical(5).BorderBottom(1).BorderColor(Colors.Black);
                });

                foreach (var item in timelineItems)
                {
                    var dict = item as IDictionary<string, object>;
                    if (dict == null) continue;

                    string dateStr = dict.ContainsKey("Date") ? ((DateTime)dict["Date"]).ToString("yyyy/MM/dd") : "";
                    string type = dict.ContainsKey("Type") ? dict["Type"].ToString() : "";
                    string refNo = dict.ContainsKey("Reference") ? dict["Reference"].ToString() : "";
                    
                    decimal total = dict.ContainsKey("TotalAmount") ? Convert.ToDecimal(dict["TotalAmount"]) : 0;
                    decimal paid = dict.ContainsKey("PaidAmount") ? Convert.ToDecimal(dict["PaidAmount"]) : 0;
                    decimal remain = dict.ContainsKey("RemainingAmount") ? Convert.ToDecimal(dict["RemainingAmount"]) : 0;

                    string displayType = type switch {
                        "Invoice" => "فاتورة مبيعات",
                        "Installment" => "قسط",
                        "Return" => "مرتجع",
                        _ => type
                    };

                    table.Cell().Element(CellStyle).Text(dateStr);
                    table.Cell().Element(CellStyle).Text($"{displayType} ({refNo})");
                    table.Cell().Element(CellStyle).AlignRight().Text($"{total:N2}");
                    table.Cell().Element(CellStyle).AlignRight().Text($"{paid:N2}").FontColor(Colors.Green.Darken2);
                    table.Cell().Element(CellStyle).AlignRight().Text($"{remain:N2}").FontColor(remain > 0 ? Colors.Red.Darken2 : Colors.Black);
                }

                static IContainer CellStyle(IContainer c) => c.BorderBottom(1).BorderColor(Colors.Grey.Lighten2).PaddingVertical(5);
            });
        });
    }
}
