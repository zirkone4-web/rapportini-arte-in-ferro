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
- rapportini pianificati dall'ufficio già pronti su tutti i telefoni della squadra;
- comunicazioni che aprono direttamente una scheda cliente o un rapportino;
- esito completato, da completare o materiale mancante;
- richieste materiali divise tra materia prima e materiale di consumo;
- notifiche push Firebase e controllo aggiornamenti Google Play all'accesso.

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
  --dart-define=SUPABASE_PUBLISHABLE_KEY=sb_publishable_... \
  --dart-define=FIREBASE_PROJECT_ID=... \
  --dart-define=FIREBASE_APP_ID=... \
  --dart-define=FIREBASE_API_KEY=... \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=...
```

Non utilizzare la chiave `service_role` nell'app.

I quattro parametri Firebase sono facoltativi: senza di essi l'app continua a
funzionare, ma non registra il telefono per le notifiche push.

## Attivazione notifiche lato Supabase

1. In Firebase creare una service account e scaricare il relativo JSON.
2. Salvare il JSON completo nei secret Supabase con nome
   `FIREBASE_SERVICE_ACCOUNT`.
3. Dalla radice del progetto distribuire la funzione:

```bash
supabase functions deploy notifiche-push
```

La funzione accetta soltanto sessioni amministrative e usa la service role
esclusivamente sul server. Non inserire mai il JSON Firebase nell'app o nel
repository.

## Aggiornamenti Google Play

La versione corrente è `0.4.0+4`. La tabella Supabase `configurazione_app`
contiene versione corrente, versione minima, URL dello store e flag di obbligo.
Quando si pubblica una versione futura, aggiornare quella riga: al successivo
accesso l'app propone **Aggiorna dal Play Store**.

## Verifica

```bash
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
```
