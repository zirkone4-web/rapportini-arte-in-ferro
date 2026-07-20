using ArteInFerro.Rapportini.Desktop.Models;
using ClosedXML.Excel;
using QuestPDF.Fluent;
using QuestPDF.Helpers;
using QuestPDF.Infrastructure;

namespace ArteInFerro.Rapportini.Desktop.Services;

public sealed class ExportService
{
    private const string IronBlue = "#12385B";
    private readonly SupabaseApiService _api;

    public ExportService(SupabaseApiService api) => _api = api;

    public Task ExportExcelAsync(
        string path,
        IReadOnlyList<ReportRow> reports,
        CancellationToken cancellationToken = default)
    {
        return Task.Run(() =>
        {
            cancellationToken.ThrowIfCancellationRequested();
            using var workbook = new XLWorkbook();
            var sheet = workbook.Worksheets.Add("Rapportini");
            var headers = new[]
            {
                "ID", "Data", "Dipendente", "Cliente", "Luogo", "Tipologia",
                "Inizio", "Fine", "Ore", "Stato", "Descrizione", "Nota ufficio",
                "Latitudine", "Longitudine", "Aggiornato il"
            };
            for (var column = 0; column < headers.Length; column++)
                sheet.Cell(1, column + 1).Value = headers[column];

            var row = 2;
            foreach (var report in reports)
            {
                sheet.Cell(row, 1).Value = report.Id;
                sheet.Cell(row, 2).Value = report.StartAt.LocalDateTime.Date;
                sheet.Cell(row, 3).Value = report.EmployeeName;
                sheet.Cell(row, 4).Value = report.ClientName;
                sheet.Cell(row, 5).Value = report.Place;
                sheet.Cell(row, 6).Value = report.InterventionLabel;
                sheet.Cell(row, 7).Value = report.StartAt.LocalDateTime;
                if (report.EndAt is not null)
                    sheet.Cell(row, 8).Value = report.EndAt.Value.LocalDateTime;
                sheet.Cell(row, 9).Value = report.TotalHours;
                sheet.Cell(row, 10).Value = report.Status;
                sheet.Cell(row, 11).Value = report.Description;
                sheet.Cell(row, 12).Value = report.AdminNote ?? string.Empty;
                if (report.Latitude is not null) sheet.Cell(row, 13).Value = report.Latitude.Value;
                if (report.Longitude is not null) sheet.Cell(row, 14).Value = report.Longitude.Value;
                sheet.Cell(row, 15).Value = report.UpdatedAt.LocalDateTime;
                row++;
            }

            var range = sheet.Range(1, 1, Math.Max(1, row - 1), headers.Length);
            range.CreateTable("TabellaRapportini");
            var header = sheet.Range(1, 1, 1, headers.Length);
            header.Style.Fill.BackgroundColor = XLColor.FromHtml("#12385B");
            header.Style.Font.FontColor = XLColor.White;
            header.Style.Font.Bold = true;
            sheet.SheetView.FreezeRows(1);
            sheet.Column(2).Style.DateFormat.Format = "dd/mm/yyyy";
            sheet.Columns(7, 8).Style.DateFormat.Format = "dd/mm/yyyy hh:mm";
            sheet.Column(9).Style.NumberFormat.Format = "0.00";
            sheet.Column(15).Style.DateFormat.Format = "dd/mm/yyyy hh:mm";
            foreach (var column in sheet.ColumnsUsed())
            {
                column.AdjustToContents();
                column.Width = Math.Clamp(column.Width, 8, 45);
            }
            sheet.Columns(11, 12).Width = 42;
            sheet.Columns(11, 12).Style.Alignment.WrapText = true;
            workbook.SaveAs(path);
        }, cancellationToken);
    }

    public async Task ExportPdfAsync(
        string path,
        ReportRow report,
        CancellationToken cancellationToken = default)
    {
        var media = await _api.GetMediaAsync(report, cancellationToken);
        await Task.Run(() => BuildPdf(report, media).GeneratePdf(path), cancellationToken);
    }

    private static IDocument BuildPdf(ReportRow report, ReportMedia media)
    {
        return Document.Create(document =>
        {
            document.Page(page =>
            {
                page.Size(PageSizes.A4);
                page.Margin(34);
                page.DefaultTextStyle(style => style.FontSize(10).FontColor(Colors.Grey.Darken3));
                page.Header().Element(container => BuildHeader(container, report));
                page.Content().PaddingTop(18).Column(column =>
                {
                    column.Spacing(14);
                    column.Item().Element(container => BuildSummary(container, report));
                    column.Item().Element(container => BuildDescription(container, report));
                    column.Item().Element(container => BuildGps(container, report));
                    if (media.Photos.Count > 0)
                        column.Item().Element(container => BuildPhotos(container, media.Photos));
                    column.Item().Element(container => BuildSignature(container, media.Signature));
                    if (!string.IsNullOrWhiteSpace(report.AdminNote))
                        column.Item().Element(container => BuildAdminNote(container, report.AdminNote!));
                });
                page.Footer().AlignCenter().Text(text =>
                {
                    text.Span("Arte in Ferro · Rapportino ");
                    text.Span(report.Id[..Math.Min(8, report.Id.Length)]);
                    text.Span(" · Pagina ");
                    text.CurrentPageNumber();
                    text.Span(" / ");
                    text.TotalPages();
                });
            });
        });
    }

    private static void BuildHeader(IContainer container, ReportRow report)
    {
        container.Row(row =>
        {
            row.RelativeItem().Column(column =>
            {
                column.Item().Text("ARTE IN FERRO").FontSize(22).Bold().FontColor(IronBlue);
                column.Item().Text("Rapportino di lavoro").FontSize(13);
            });
            row.ConstantItem(150).AlignRight().Column(column =>
            {
                column.Item().Text(report.Status.ToUpperInvariant()).Bold().FontColor(IronBlue);
                column.Item().Text($"N. {report.Id[..Math.Min(8, report.Id.Length)]}");
                column.Item().Text(report.StartAt.LocalDateTime.ToString("dd/MM/yyyy"));
            });
        });
    }

    private static void BuildSummary(IContainer container, ReportRow report)
    {
        container.Border(1).BorderColor(Colors.Grey.Lighten2).Padding(12).Table(table =>
        {
            table.ColumnsDefinition(columns =>
            {
                columns.ConstantColumn(105);
                columns.RelativeColumn();
                columns.ConstantColumn(85);
                columns.RelativeColumn();
            });
            AddCell(table, "Dipendente", report.EmployeeName);
            AddCell(table, "Cliente", report.ClientName);
            AddCell(table, "Luogo", report.Place);
            AddCell(table, "Intervento", report.InterventionLabel);
            AddCell(table, "Inizio", report.StartAt.LocalDateTime.ToString("dd/MM/yyyy HH:mm"));
            AddCell(table, "Fine", report.EndAt?.LocalDateTime.ToString("dd/MM/yyyy HH:mm") ?? "—");
            AddCell(table, "Ore totali", report.TotalHours.ToString("0.00"));
            AddCell(table, "Riferimento", report.AppointmentReference ?? "—");
        });
    }

    private static void AddCell(TableDescriptor table, string label, string value)
    {
        table.Cell().PaddingVertical(4).Text(label).SemiBold().FontColor(IronBlue);
        table.Cell().PaddingVertical(4).Text(value);
    }

    private static void BuildDescription(IContainer container, ReportRow report)
    {
        container.Column(column =>
        {
            column.Item().Text("LAVORO SVOLTO").Bold().FontColor(IronBlue);
            column.Item().PaddingTop(5).BorderBottom(1).BorderColor(Colors.Grey.Lighten2)
                .PaddingBottom(9).Text(report.Description);
        });
    }

    private static void BuildGps(IContainer container, ReportRow report)
    {
        var value = report.Latitude is null || report.Longitude is null
            ? "Posizione non disponibile"
            : $"{report.Latitude:0.000000}, {report.Longitude:0.000000}" +
              (report.GpsAccuracy is null ? string.Empty : $" · precisione {report.GpsAccuracy:0} m");
        container.Text(text =>
        {
            text.Span("POSIZIONE GPS  ").Bold().FontColor(IronBlue);
            text.Span(value);
        });
    }

    private static void BuildPhotos(IContainer container, IReadOnlyList<byte[]> photos)
    {
        container.Column(column =>
        {
            column.Item().Text("FOTO CANTIERE").Bold().FontColor(IronBlue);
            for (var index = 0; index < photos.Count; index += 2)
            {
                var first = photos[index];
                var second = index + 1 < photos.Count ? photos[index + 1] : null;
                column.Item().PaddingTop(6).Row(row =>
                {
                    row.RelativeItem().Height(135).Image(first).FitArea();
                    row.ConstantItem(8);
                    if (second is not null)
                        row.RelativeItem().Height(135).Image(second).FitArea();
                    else
                        row.RelativeItem();
                });
            }
        });
    }

    private static void BuildSignature(IContainer container, byte[]? signature)
    {
        container.Row(row =>
        {
            row.RelativeItem();
            row.ConstantItem(230).Column(column =>
            {
                column.Item().Text("FIRMA CLIENTE").Bold().FontColor(IronBlue);
                if (signature is not null)
                    column.Item().Height(90).PaddingTop(5).Image(signature).FitArea();
                else
                    column.Item().Height(70).AlignMiddle().Text("Firma non disponibile").Italic();
                column.Item().BorderTop(1).BorderColor(Colors.Grey.Darken1);
            });
        });
    }

    private static void BuildAdminNote(IContainer container, string note)
    {
        container.Background(Colors.Grey.Lighten3).Padding(10).Text(text =>
        {
            text.Span("NOTA UFFICIO  ").Bold().FontColor(IronBlue);
            text.Span(note);
        });
    }
}
