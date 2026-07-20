# Dashboard Windows — Arte in Ferro

Applicazione amministrativa nativa WPF per Windows 10/11 a 64 bit.

## Funzioni incluse

- autenticazione Supabase riservata agli amministratori attivi;
- tabella con filtri per periodo, dipendente, cliente e stato;
- modifica completa e controllo di concorrenza tramite `versione`;
- approvazione e rifiuto con nota obbligatoria in caso di rifiuto;
- esportazione dei dati filtrati in Excel `.xlsx`;
- PDF professionale del singolo rapportino con GPS, firma e fino a 6 foto;
- accesso agli allegati mediante URL firmati temporanei, senza bucket pubblici.

## Configurazione

Modificare `ArteInFerro.Rapportini.Desktop/appsettings.json`:

```json
{
  "SupabaseUrl": "https://PROJECT_REF.supabase.co",
  "SupabasePublishableKey": "sb_publishable_..."
}
```

In alternativa impostare `SUPABASE_URL` e `SUPABASE_PUBLISHABLE_KEY`.
Non usare mai la chiave `service_role` nel programma.

## Avvio e pubblicazione

Con .NET 8 SDK su Windows:

```powershell
cd apps/windows/ArteInFerro.Rapportini.Desktop
dotnet restore
dotnet run
```

Pacchetto autonomo per PC senza .NET preinstallato:

```powershell
dotnet publish -c Release -r win-x64 --self-contained true `
  -p:PublishSingleFile=true `
  -p:IncludeNativeLibrariesForSelfExtract=true `
  -o publish
```

Il workflow GitHub incluso esegue questa pubblicazione e produce uno ZIP.

## Licenza PDF

Il progetto imposta QuestPDF `LicenseType.Community`. Prima della distribuzione
commerciale verificare l'idoneità alla licenza Community sul sito QuestPDF;
se l'organizzazione non rientra nei requisiti, acquistare e impostare la licenza
appropriata.
