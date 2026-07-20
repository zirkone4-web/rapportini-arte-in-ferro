using System.Windows;
using System.Windows.Controls;
using ArteInFerro.Rapportini.Desktop.ViewModels;

namespace ArteInFerro.Rapportini.Desktop.Views;

public partial class LoginWindow : Window
{
    private readonly LoginViewModel _viewModel;

    public LoginWindow(LoginViewModel viewModel)
    {
        InitializeComponent();
        _viewModel = viewModel;
        DataContext = viewModel;
    }

    private void PasswordChanged(object sender, RoutedEventArgs e)
    {
        _viewModel.Password = ((PasswordBox)sender).Password;
    }
}
