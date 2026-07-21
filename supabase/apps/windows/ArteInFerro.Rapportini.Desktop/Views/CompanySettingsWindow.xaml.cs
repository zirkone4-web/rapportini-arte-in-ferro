using System.Windows;
using ArteInFerro.Rapportini.Desktop.ViewModels;
namespace ArteInFerro.Rapportini.Desktop.Views;
public partial class CompanySettingsWindow : Window
{
    public CompanySettingsWindow(CompanySettingsViewModel viewModel) { InitializeComponent(); DataContext = viewModel; }
}
