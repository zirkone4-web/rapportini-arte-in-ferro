using System.Windows;
using ArteInFerro.Rapportini.Desktop.ViewModels;

namespace ArteInFerro.Rapportini.Desktop.Views;

public partial class MasterDataWindow : Window
{
    public MasterDataWindow(MasterDataViewModel viewModel)
    {
        InitializeComponent();
        DataContext = viewModel;
    }
}
