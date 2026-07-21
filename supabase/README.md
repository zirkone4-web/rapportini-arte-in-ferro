# Rapportini Arte in Ferro

Soluzione B2B composta da app Flutter per i dipendenti, dashboard Windows WPF
per l'ufficio e backend Supabase condiviso.

## Cosa è incluso

| Modulo | Tecnologia | Funzioni principali |
|---|---|---|
| Mobile | Flutter, BLoC, SQLite | Login, bozze offline, orari, GPS, foto JPEG compresse, firma touch, sincronizzazione |
| Windows | .NET 8 WPF, MVVM | Filtri, modifica, approvazione/rifiuto, PDF, Excel |
| Cloud | Supabase/PostgreSQL | Auth, RBAC, RLS, trigger ore/versione, Storage privato |

Il telefono salva sempre prima in SQLite. Quando torna la rete, invia i dati e
gli allegati a Supabase. Il programma Windows vede gli stessi rapportini in tempo
reale al successivo aggiornamento, senza collegamenti diretti tra PC e telefono.

## Struttura

```text
apps/mobile/                                  app Flutter Android/iOS
apps/windows/ArteInFerro.Rapportini.Desktop/ dashboard Windows
supabase/supabase_seed_demo.sql               clienti dimostrativi
tools/                                        generazione piattaforme mobile
.github/workflows/build-installers.yml        build APK e ZIP Windows
```

Lo schema completo è in `supabase/supabase_rapportini_schema.sql`.

## Preparazione Supabase

1. Creare un progetto su Supabase.
2. Aprire **SQL Editor**, incollare ed eseguire
   `supabase/supabase_rapportini_schema.sql`.
3. Eseguire `supabase/supabase_seed_demo.sql` per avere tre clienti di prova.
4. Da **Authentication > Users**, creare almeno due account email/password:
   un amministratore e un operatore. Il trigger crea automaticamente i profili.
5. Promuovere il primo account amministratore:

```sql
update public.utenti
set ruolo = 'admin'
where email = 'tua-email@azienda.it';
```

6. Da **Connect** copiare Project URL e Publishable key. La `service_role` non
   deve mai essere inserita nelle app.

## Provare l'app mobile

Richiede Flutter stabile, Python 3 e Android SDK:

```bash
bash tools/bootstrap_mobile.sh
cd apps/mobile
flutter run \
  --dart-define=SUPABASE_URL=https://PROJECT_REF.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
```

Per creare manualmente l'APK:

```bash
flutter build apk --release \
  --dart-define=SUPABASE_URL=https://PROJECT_REF.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
```

L'APK sarà in `apps/mobile/build/app/outputs/flutter-apk/app-release.apk`.
La build iOS richiede macOS, Xcode e la firma Apple del proprietario dell'app.

## Provare il software Windows

Inserire URL e Publishable key in
`apps/windows/ArteInFerro.Rapportini.Desktop/appsettings.json`, quindi su Windows:

```powershell
cd apps/windows/ArteInFerro.Rapportini.Desktop
dotnet restore
dotnet run
```

Accedere con l'account promosso ad `admin`.

## Ottenere APK e programma Windows senza compilare a mano

Il workflow `.github/workflows/build-installers.yml` prepara entrambi i pacchetti.
In un repository GitHub:

1. aggiungere i secret `SUPABASE_URL` e `SUPABASE_PUBLISHABLE_KEY`;
2. aprire **Actions > Build APK e Windows > Run workflow**;
3. scaricare gli artifact `rapportini-android-apk` e
   `rapportini-windows-x64`.

## Controlli di qualità

Il workflow esegue `flutter analyze`, i test Flutter e la compilazione Release
.NET. Il database applica RLS anche se un client viene manomesso: gli operatori
vedono soltanto i propri rapportini, mentre gli amministratori possono gestire
tutti i dati.
