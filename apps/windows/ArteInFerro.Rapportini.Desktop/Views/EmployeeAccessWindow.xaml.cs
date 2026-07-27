using System.Windows;
using ArteInFerro.Rapportini.Desktop.Services;
using ArteInFerro.Rapportini.Desktop.ViewModels;

namespace ArteInFerro.Rapportini.Desktop.Views;

public partial class EmployeeAccessWindow : Window
{
    private readonly SupabaseApiService _api;
    private readonly EmployeeAccessViewModel _viewModel;

    public EmployeeAccessWindow(EmployeeAccessViewModel viewModel, SupabaseApiService api)
    {
        InitializeComponent();
        _api = api;
        _viewModel = viewModel;
        DataContext = viewModel;
    }

    private async void CreateUserClick(object sender, RoutedEventArgs e)
    {
        var window = new EmployeeCreateWindow(new EmployeeCreateViewModel(_api)) { Owner = this };
        if (window.ShowDialog() == true)
            await _viewModel.LoadAsync();
    }
}
