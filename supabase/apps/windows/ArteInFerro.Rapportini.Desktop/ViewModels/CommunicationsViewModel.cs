using System.Collections.ObjectModel;
using ArteInFerro.Rapportini.Desktop.Services;
using CommunityToolkit.Mvvm.ComponentModel;
using CommunityToolkit.Mvvm.Input;

namespace ArteInFerro.Rapportini.Desktop.ViewModels;

public partial class CommunicationsViewModel : ObservableObject
{
    private readonly SupabaseApiService _api;
    [ObservableProperty] private string _title = string.Empty;
    [ObservableProperty] private string _message = string.Empty;
    [ObservableProperty] private string _priority = "normale";
    [ObservableProperty] private bool _requireConfirmation;
    [ObservableProperty] private bool _isBusy;
    [ObservableProperty] private string _status = "Seleziona i destinatari.";

    public CommunicationsViewModel(SupabaseApiService api)
    {
        _api = api;
        _ = LoadAsync();
    }

    public ObservableCollection<RecipientChoice> Recipients { get; } = [];

    private async Task LoadAsync()
    {
        try
        {
            var employees = await _api.GetEmployeesAsync();
            Recipients.Clear();
            foreach (var item in employees)
                Recipients.Add(new RecipientChoice(item.Id, item.Label));
        }
        catch (Exception ex) { Status = ex.Message; }
    }

    [RelayCommand]
    private void SelectAll()
    {
        foreach (var item in Recipients) item.IsSelected = true;
        Status = $"{Recipients.Count} destinatari selezionati";
    }

    [RelayCommand]
    private async Task SendAsync()
    {
        var selected = Recipients.Where(x => x.IsSelected).Select(x => x.Id).ToList();
        if (Title.Trim().Length < 2 || Message.Trim().Length < 2 || selected.Count == 0)
        {
            Status = "Inserisci titolo, messaggio e almeno un destinatario.";
            return;
        }
        IsBusy = true;
        try
        {
            await _api.SendCommunicationAsync(
                Title, Message, Priority, RequireConfirmation, selected);
            Status = $"Comunicazione inviata a {selected.Count} dipendenti.";
            Title = Message = string.Empty;
            RequireConfirmation = false;
            foreach (var item in Recipients) item.IsSelected = false;
        }
        catch (Exception ex) when (ex is ApiException or HttpRequestException or TaskCanceledException)
        {
            Status = ex.Message;
        }
        finally { IsBusy = false; }
    }
}

public partial class RecipientChoice : ObservableObject
{
    public RecipientChoice(string id, string name)
    {
        Id = id;
        Name = name;
    }
    public string Id { get; }
    public string Name { get; }
    [ObservableProperty] private bool _isSelected;
}
