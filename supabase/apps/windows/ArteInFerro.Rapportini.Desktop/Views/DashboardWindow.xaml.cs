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

    private async void NewEmployeeClick(object sender, RoutedEventArgs e)
    {
        var viewModel = new EmployeeCreateViewModel(_api);
        var window = new EmployeeCreateWindow(viewModel) { Owner = this };
        if (window.ShowDialog() == true)
            await _viewModel.LoadAsync();
    }

    private void EmployeeAccessClick(object sender, RoutedEventArgs e) =>
        new EmployeeAccessWindow(new EmployeeAccessViewModel(_api)) { Owner = this }.ShowDialog();

    private void AttendanceClick(object sender, RoutedEventArgs e) =>
        new AttendanceWindow(new AttendanceViewModel(_api)) { Owner = this }.ShowDialog();

    private void DeadlinesClick(object sender, RoutedEventArgs e) =>
        new DeadlinesWindow(_viewModel) { Owner = this }.ShowDialog();

    private void EmployeeDocumentsClick(object sender, RoutedEventArgs e) =>
        new EmployeeDocumentsWindow(new EmployeeDocumentsViewModel(_api)) { Owner = this }.ShowDialog();

    private void CommunicationsClick(object sender, RoutedEventArgs e) =>
        new CommunicationsWindow(new CommunicationsViewModel(_api)) { Owner = this }.ShowDialog();

    private void FleetClick(object sender, RoutedEventArgs e) =>
        new FleetWindow(new FleetViewModel(_api)) { Owner = this }.ShowDialog();

    private void OperationsClick(object sender, RoutedEventArgs e) =>
        new OperationsWindow(new OperationsViewModel(_api)) { Owner = this }.ShowDialog();

    private void CompanyCertificationsClick(object sender, RoutedEventArgs e) =>
        new CompanyCertificationsWindow(new CompanyCertificationsViewModel(_api))
            { Owner = this }.ShowDialog();

    private void CompanySettingsClick(object sender, RoutedEventArgs e) =>
        new CompanySettingsWindow(new CompanySettingsViewModel(_api)) { Owner = this }.ShowDialog();

    private void MasterDataClick(object sender, RoutedEventArgs e) =>
        new MasterDataWindow(new MasterDataViewModel(_api)) { Owner = this }.ShowDialog();
}
