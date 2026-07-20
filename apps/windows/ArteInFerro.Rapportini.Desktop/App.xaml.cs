using System.Windows;
using ArteInFerro.Rapportini.Desktop.Services;
using ArteInFerro.Rapportini.Desktop.ViewModels;
using ArteInFerro.Rapportini.Desktop.Views;
using QuestPDF.Infrastructure;

namespace ArteInFerro.Rapportini.Desktop;

public partial class App : Application
{
    private HttpClient? _httpClient;

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);
        QuestPDF.Settings.License = LicenseType.Community;

        try
        {
            var settings = AppSettings.Load();
            _httpClient = new HttpClient { Timeout = TimeSpan.FromSeconds(45) };
            var auth = new SupabaseAuthService(_httpClient, settings);
            var loginViewModel = new LoginViewModel(auth);
            var loginWindow = new LoginWindow(loginViewModel);
            loginViewModel.LoginSucceeded += session =>
            {
                var api = new SupabaseApiService(_httpClient, settings, session);
                var exports = new ExportService(api);
                var dashboardViewModel = new DashboardViewModel(api, exports);
                var dashboard = new DashboardWindow(dashboardViewModel, api);
                MainWindow = dashboard;
                dashboard.Show();
                loginWindow.Close();
            };
            MainWindow = loginWindow;
            loginWindow.Show();
        }
        catch (Exception ex)
        {
            MessageBox.Show(
                ex.Message,
                "Configurazione non valida",
                MessageBoxButton.OK,
                MessageBoxImage.Error);
            Shutdown(1);
        }
    }

    protected override void OnExit(ExitEventArgs e)
    {
        _httpClient?.Dispose();
        base.OnExit(e);
    }
}
