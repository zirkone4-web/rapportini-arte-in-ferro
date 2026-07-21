using System.Windows;
using ArteInFerro.Rapportini.Desktop.ViewModels;

namespace ArteInFerro.Rapportini.Desktop.Views;

public partial class EmployeeDocumentsWindow : Window
{
    public EmployeeDocumentsWindow(EmployeeDocumentsViewModel viewModel)
    {
        InitializeComponent();
        DataContext = viewModel;
    }
}
