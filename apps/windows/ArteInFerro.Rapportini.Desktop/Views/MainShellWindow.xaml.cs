using System.Windows;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Media;
using System.Windows.Media.Animation;
using System.Media;
using ArteInFerro.Rapportini.Desktop.Models;
using ArteInFerro.Rapportini.Desktop.Services;
using ArteInFerro.Rapportini.Desktop.ViewModels;

namespace ArteInFerro.Rapportini.Desktop.Views;

public partial class MainShellWindow : Window
{
    private readonly DashboardViewModel _viewModel;
    private readonly SupabaseApiService _api;

    public MainShellWindow(DashboardViewModel viewModel, SupabaseApiService api)
    {
        InitializeComponent();
        _viewModel = viewModel;
        _api = api;
        DataContext = viewModel;
        viewModel.EditRequested += OpenEditor;
        Closed += (_, _) => viewModel.EditRequested -= OpenEditor;
    }

    private void PlayIntro()
    {
        var duration = TimeSpan.FromSeconds(3);
        if (IntroBackground.RenderTransform is ScaleTransform backgroundScale)
        {
            backgroundScale.BeginAnimation(
                ScaleTransform.ScaleXProperty,
                new DoubleAnimation(1.22, 1, duration));
            backgroundScale.BeginAnimation(
                ScaleTransform.ScaleYProperty,
                new DoubleAnimation(1.22, 1, duration));
        }

        var logoFade = new DoubleAnimation(0, 1, TimeSpan.FromMilliseconds(900))
        {
            BeginTime = TimeSpan.FromMilliseconds(1700)
        };
        IntroLogo.BeginAnimation(OpacityProperty, logoFade);
        if (IntroLogo.RenderTransform is ScaleTransform logoScale)
        {
            var scale = new DoubleAnimation(.55, 1, TimeSpan.FromMilliseconds(900))
            {
                BeginTime = TimeSpan.FromMilliseconds(1700),
                EasingFunction = new BackEase { EasingMode = EasingMode.EaseOut }
            };
            logoScale.BeginAnimation(ScaleTransform.ScaleXProperty, scale);
            logoScale.BeginAnimation(ScaleTransform.ScaleYProperty, scale);
        }

        var close = new DoubleAnimation(1, 0, TimeSpan.FromMilliseconds(450))
        {
            BeginTime = TimeSpan.FromMilliseconds(3100)
        };
        close.Completed += (_, _) => IntroOverlay.Visibility = Visibility.Collapsed;
        IntroOverlay.BeginAnimation(OpacityProperty, close);
        _ = Task.Delay(2200).ContinueWith(
            _ => Dispatcher.Invoke(() => SystemSounds.Asterisk.Play()));
    }

    private void SkipIntroClick(object sender, MouseButtonEventArgs e)
    {
        IntroOverlay.BeginAnimation(OpacityProperty, null);
        IntroOverlay.Visibility = Visibility.Collapsed;
    }

    private void ShowPanel(UIElement panel, string title)
    {
        HomePanel.Visibility = Visibility.Collapsed;
        ReportsPanel.Visibility = Visibility.Collapsed;
        PlanningPanel.Visibility = Visibility.Collapsed;

        panel.Visibility = Visibility.Visible;
        PageTitle.Text = title;
    }

    private void DashboardClick(object sender, RoutedEventArgs e) =>
        ShowPanel(HomePanel, "Dashboard");

    private void ReportsClick(object sender, RoutedEventArgs e) =>
        ShowPanel(ReportsPanel, "Rapportini");

    private void PlanningClick(object sender, RoutedEventArgs e) =>
        ShowPanel(PlanningPanel, "Pianificazione lavori");

    private void PlanningDayClick(object sender, RoutedEventArgs e) =>
        _viewModel.SetPlanningView(true);

    private void PlanningWeekClick(object sender, RoutedEventArgs e) =>
        _viewModel.SetPlanningView(false);

    private void PlanningPreviousClick(object sender, RoutedEventArgs e) =>
        _viewModel.MovePlanningPeriod(-1);

    private void PlanningNextClick(object sender, RoutedEventArgs e) =>
        _viewModel.MovePlanningPeriod(1);

    private void PlanningTodayClick(object sender, RoutedEventArgs e) =>
        _viewModel.PlanningToday();

    private void RowMenuButtonClick(object sender, RoutedEventArgs e)
    {
        if (sender is not Button button) return;
        button.ContextMenu.PlacementTarget = button;
        button.ContextMenu.IsOpen = true;
        e.Handled = true;
    }

    private static ReportRow? MenuReport(object sender) =>
        (sender as MenuItem)?.DataContext as ReportRow;

    private void OpenReportMenuClick(object sender, RoutedEventArgs e)
    {
        if (MenuReport(sender) is { } report) OpenEditor(report);
    }

    private void ExportReportMenuClick(object sender, RoutedEventArgs e)
    {
        if (MenuReport(sender) is not { } report) return;
        _viewModel.SelectedReport = report;
        if (_viewModel.ExportPdfCommand.CanExecute(null))
            _viewModel.ExportPdfCommand.Execute(null);
    }

    private async void CancelPlanningMenuClick(object sender, RoutedEventArgs e)
    {
        if (MenuReport(sender) is not { } report) return;
        if (MessageBox.Show(
                "Annullare questa pianificazione? Rimarrà nello storico.",
                "Conferma annullamento",
                MessageBoxButton.YesNo,
                MessageBoxImage.Question) == MessageBoxResult.Yes)
            await _viewModel.CancelPlanningAsync(report);
    }

    private async void DeleteReportMenuClick(object sender, RoutedEventArgs e)
    {
        if (MenuReport(sender) is not { } report) return;
        if (MessageBox.Show(
                $"Cancellare definitivamente il rapportino di {report.EmployeeName}?",
                "Conferma cancellazione",
                MessageBoxButton.YesNo,
                MessageBoxImage.Warning) == MessageBoxResult.Yes)
            await _viewModel.DeleteReportAsync(report);
    }

    private async void NewReportClick(object sender, RoutedEventArgs e)
    {
        var window = new PlanningCreateWindow(_api, isPlanned: false) { Owner = this };
        if (window.ShowDialog() == true)
            await _viewModel.LoadAsync();
    }

    private async void NewPlanningClick(object sender, RoutedEventArgs e)
    {
        var window = new PlanningCreateWindow(_api, isPlanned: true) { Owner = this };
        if (window.ShowDialog() == true)
            await _viewModel.LoadAsync();
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
        new EmployeeAccessWindow(new EmployeeAccessViewModel(_api), _api) { Owner = this }.ShowDialog();

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
