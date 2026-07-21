using System.Windows;
using ArteInFerro.Rapportini.Desktop.ViewModels;

namespace ArteInFerro.Rapportini.Desktop.Views;

public partial class EmployeeCreateWindow : Window
{
    public EmployeeCreateWindow(EmployeeCreateViewModel viewModel)
    {
        InitializeComponent();
        DataContext = viewModel;
        viewModel.Saved += () => DialogResult = true;
    }
}
