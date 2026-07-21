using System.Windows;
using ArteInFerro.Rapportini.Desktop.ViewModels;

namespace ArteInFerro.Rapportini.Desktop.Views;

public partial class EmployeeAccessWindow : Window
{
    public EmployeeAccessWindow(EmployeeAccessViewModel viewModel)
    {
        InitializeComponent();
        DataContext = viewModel;
    }
}
