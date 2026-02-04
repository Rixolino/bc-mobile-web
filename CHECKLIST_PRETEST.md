# Checklist Notifiche Treni v3 - Verifica Pre-Deploy

## Compilazione & Build
- [ ] `flutter clean` eseguito
- [ ] `flutter pub get` completato
- [ ] `flutter analyze` senza errori
- [ ] Kotlin compila senza errori

## Kotlin Modifications
- [ ] RealtimeService.kt contiene i 4 log principali:
  - [ ] `Trip X fetched JSON:`
  - [ ] `body same as cached` / `body differs from cached`
  - [ ] `STATE CHANGED:` (con PREV e NEW)
  - [ ] `>>> SENDING NOTIFICATION`
- [ ] State fingerprint ha 7 campi: nextStop, eventType, nextArrival, lastPassed, delay, remaining, minutesToArrival
- [ ] onCreate() log aggiunto

## Documentazione
- [ ] NOTIFICHE_DEBUG.md creato (guida step-by-step)
- [ ] NOTIFICHE_LOGGING_SUMMARY.md creato (technical summary)
- [ ] STATUS_NOTIFICHE_2025.md creato (status report)
- [ ] capture_logs.bat creato (script per catturare log)

## Pre-Test Checklist
- [ ] Device Android collegato via USB
- [ ] Debug USB abilitato
- [ ] Logcat funzionante in Android Studio
- [ ] App buildabile su device

## Test Steps (Manuale)
1. [ ] Build app: `flutter run`
2. [ ] Apri Logcat in Android Studio
3. [ ] Filtra per: `RealtimeService`
4. [ ] Apri app → Train Details di un treno IC/E/etc.
5. [ ] Premi "Monitor Train" button
6. [ ] Osserva Logcat per 120 secondi (2 minuti)
7. [ ] Annota:
   - [ ] Quante volte appare `body differs from cached`?
   - [ ] Quante volte appare `STATE CHANGED`?
   - [ ] Quante volte appare `>>> SENDING NOTIFICATION`?
   - [ ] Se apparizioni = 0 → scrivi il motivo

## Esperienza Utente (UI)
- [ ] Notifica treno compare sul device
- [ ] Notifica contiene:
   - [ ] Prossima fermata
   - [ ] Ritardo
   - [ ] Fermate rimanenti
   - [ ] Stato attuale
- [ ] Notifica si aggiorna quando stato cambia
- [ ] Nessuno spam di notifiche (massimo ogni 10-30 sec)

## Bug Known (Accettato)
- ⚠️ Se il server è congelato → non è colpa dell'app
- ⚠️ Se ci sono piccole variazioni nel JSON ma lo stato rimane uguale → CORRETTO (evita spam)
- ⚠️ Se il treno arriva a destinazione → il monitoraggio si ferma (ESPERANTO)

## Problemi Trovati (Da Risolvere)
| Problema | Stato | Note |
|----------|-------|-------|
| Server congelato | ⏳ TBD | Dipende dal server, non app |
| Notifiche non visibili | ⏳ TBD | Possibile bug Android o permessi |
| Dati UI ≠ dati Notifica | ⏳ TODO | Train_details_sheet logica ancora non replicata in Dart |
| Performance | ⏳ TBD | Dipende dall'intervallo polling |

## Per Debug Avanzato
Se i problemi persistono, raccogli:
1. [ ] Cattura Logcat completa (60-120 sec)
2. [ ] Screenshot della UI train_details
3. [ ] Screenshot della notifica
4. [ ] JSON API response (prima e dopo)
5. [ ] Quale treno? Quale provider (IT/DE/CH)?
6. [ ] Quale orario approssimativo?

---

## Note Importanti

### ⚠️ Questo è SOLO il Layer di Logging
Non abbiamo ancora:
- [ ] Replicato completamente la logica di train_details_sheet.dart in Dart notification_manager_provider.dart
- [ ] Testato su device reale
- [ ] Verificato che il server fornisce dati aggiornati

### ✅ Quello che fatto SERVE A:
1. Diagnosticare se il problema è dal server o dall'app
2. Identificare esattamente quale step non funziona
3. Fornire dati per il debug in Fase 2

### 📋 Prossima Fase:
Dopo aver raccolto i log:
1. Analizzare i log raccolti
2. Identificare root cause
3. Implementare soluzione (potrebbe essere replicare train_details_sheet logica oppure aspettare server)

---

## Quick Commands

### Build & Run
```bash
cd mobile_app
flutter clean
flutter pub get
flutter run
```

### Capture Logs (Windows)
```bash
# Opzione 1: Usare capture_logs.bat
capture_logs.bat

# Opzione 2: Manuale con adb
adb logcat RealtimeService:V *:S > log.txt
```

### Capture Logs (macOS/Linux)
```bash
adb logcat RealtimeService:V "*:S" > log_$(date +%s).txt
```

### Filtrare i Log Dopo
```bash
# Nel file log.txt, cercare key messages
grep "body differs" log.txt | wc -l
grep "STATE CHANGED" log.txt | wc -l
grep "SENDING NOTIFICATION" log.txt | wc -l
```

---

**Last Updated:** 2025-01-15
**Author:** Developer
**Status:** ✅ Logging v3 Ready for Testing
