# App mobile Rapportini

App Flutter Android/iOS per operatori sul campo.

Il backend va preparato con `supabase/supabase_rapportini_schema.sql` dalla
radice del progetto.

## Funzioni

- login Supabase e sessione persistente;
- database SQLite locale e coda di sincronizzazione;
- creazione e modifica di bozze o rapportini respinti;
- cliente, intervento, luogo, orari e descrizione;
- GPS ad alta precisione rilevato al salvataggio;
- foto dalla fotocamera ridimensionate a massimo 1920×1080 e JPEG qualità 76;
- firma cliente touch salvata in PNG;
- invio differito quando il dispositivo è offline;
- controllo versione per evitare sovrascritture silenziose.

## Prima generazione delle piattaforme

Dalla radice del progetto:

```bash
bash tools/bootstrap_mobile.sh
```

Lo script esegue `flutter create`, aggiunge i permessi fotocamera/GPS/Internet
ad Android e le descrizioni privacy richieste da iOS, quindi scarica i package.

## Avvio

```bash
cd apps/mobile
flutter run \
  --dart-define=SUPABASE_URL=https://PROJECT_REF.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_...
```

Non utilizzare la chiave `service_role` nell'app.

## Verifica

```bash
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
```
