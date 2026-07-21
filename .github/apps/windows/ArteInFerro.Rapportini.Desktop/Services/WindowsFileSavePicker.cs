using Microsoft.Win32;

namespace ArteInFerro.Rapportini.Desktop.Services;

public sealed class WindowsFileSavePicker
{
    public string? PickExcelPath() => Pick(
        "Cartella di lavoro Excel (*.xlsx)|*.xlsx",
        $"Rapportini_{DateTime.Now:yyyyMMdd}.xlsx");

    public string? PickPdfPath(string reportId) => Pick(
        "Documento PDF (*.pdf)|*.pdf",
        $"Rapportino_{reportId[..Math.Min(8, reportId.Length)]}.pdf");

    public string? PickAttendanceExcelPath() => Pick(
        "Cartella di lavoro Excel (*.xlsx)|*.xlsx",
        $"Presenze_e_straordinari_{DateTime.Now:yyyyMMdd}.xlsx");

    private static string? Pick(string filter, string fileName)
    {
        var dialog = new SaveFileDialog
        {
            Filter = filter,
            FileName = fileName,
            AddExtension = true,
            OverwritePrompt = true
        };
        return dialog.ShowDialog() == true ? dialog.FileName : null;
    }
}
