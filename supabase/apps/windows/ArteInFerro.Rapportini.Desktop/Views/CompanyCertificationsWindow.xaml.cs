using System.Windows;
using ArteInFerro.Rapportini.Desktop.ViewModels;

namespace ArteInFerro.Rapportini.Desktop.Views;

public partial class CompanyCertificationsWindow : Window
{
    public CompanyCertificationsWindow(CompanyCertificationsViewModel viewModel)
    {
        InitializeComponent();
        DataContext = viewModel;
    }
}
