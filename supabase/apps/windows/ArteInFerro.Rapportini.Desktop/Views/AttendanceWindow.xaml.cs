using System.Windows;
using ArteInFerro.Rapportini.Desktop.ViewModels;

namespace ArteInFerro.Rapportini.Desktop.Views;

public partial class AttendanceWindow : Window
{
    public AttendanceWindow(AttendanceViewModel viewModel)
    {
        InitializeComponent();
        DataContext = viewModel;
    }
}
