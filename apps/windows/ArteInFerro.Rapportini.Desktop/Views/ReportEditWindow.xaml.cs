using System.Windows;
using ArteInFerro.Rapportini.Desktop.ViewModels;

namespace ArteInFerro.Rapportini.Desktop.Views;

public partial class ReportEditWindow : Window
{
    public ReportEditWindow(ReportEditViewModel viewModel)
    {
        InitializeComponent();
        DataContext = viewModel;
    }
}
