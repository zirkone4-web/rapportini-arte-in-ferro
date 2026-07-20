using System.Windows;
using System.Windows.Input;
using ArteInFerro.Rapportini.Desktop.Models;
using ArteInFerro.Rapportini.Desktop.Services;
using ArteInFerro.Rapportini.Desktop.ViewModels;

namespace ArteInFerro.Rapportini.Desktop.Views;

public partial class DashboardWindow : Window
{
    private readonly DashboardViewModel _viewModel;
    private readonly SupabaseApiService _api;

    public DashboardWindow(DashboardViewModel viewModel, SupabaseApiService api)
    {
        InitializeComponent();
        _viewModel = viewModel;
        _api = api;
        DataContext = viewModel;
        viewModel.EditRequested += OpenEditor;
    }

    private void ReportDoubleClick(object sender, MouseButtonEventArgs e)
    {
        if (_viewModel.EditCommand.CanExecute(null))
            _viewModel.EditCommand.Execute(null);
    }

    private void OpenEditor(ReportRow report)
    {
        var editorViewModel = new ReportEditViewModel(_api, report);
        var editor = new ReportEditWindow(editorViewModel) { Owner = this };
        editorViewModel.Saved += async () =>
        {
            editor.DialogResult = true;
            await _viewModel.RefreshAfterEditAsync();
        };
        editor.ShowDialog();
    }
}
