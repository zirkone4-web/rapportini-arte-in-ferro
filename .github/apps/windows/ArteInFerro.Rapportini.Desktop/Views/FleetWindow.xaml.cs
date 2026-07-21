using System.Windows;
using ArteInFerro.Rapportini.Desktop.ViewModels;

namespace ArteInFerro.Rapportini.Desktop.Views;

public partial class FleetWindow : Window
{
    public FleetWindow(FleetViewModel viewModel)
    {
        InitializeComponent();
        DataContext = viewModel;
    }
}
