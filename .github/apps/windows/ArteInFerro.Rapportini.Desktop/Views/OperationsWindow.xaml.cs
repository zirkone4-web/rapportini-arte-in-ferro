using System.Windows; using ArteInFerro.Rapportini.Desktop.ViewModels;
namespace ArteInFerro.Rapportini.Desktop.Views;
public partial class OperationsWindow : Window { public OperationsWindow(OperationsViewModel vm) { InitializeComponent(); DataContext = vm; } }
