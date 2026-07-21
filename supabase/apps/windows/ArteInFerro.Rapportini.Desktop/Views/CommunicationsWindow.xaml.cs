using System.Windows;
using ArteInFerro.Rapportini.Desktop.ViewModels;

namespace ArteInFerro.Rapportini.Desktop.Views;

public partial class CommunicationsWindow : Window
{
    public CommunicationsWindow(CommunicationsViewModel viewModel)
    {
        InitializeComponent();
        DataContext = viewModel;
    }
}
