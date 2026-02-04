# Status Report Notifiche Treni - 2025-01-15

## Overview
La feature notifiche treni è stata inizialmente implementata ma presentava dei problemi di "congelamento" dei dati. Abbiamo aggiunto un **layer di logging dettagliato** per diagnosticare se il problema è dal server o dall'app.

## Stato Attuale

### ✅ Completato
1. **Notification Channel Infrastructure**
   - ✅ Canale separato per treni: `CHANNEL_TRAINS`
   - ✅ Canale per proximity alert: `CHANNEL_TRAIN_PROXIMITY`
   - ✅ Notifiche separate da autobus e aerei

2. **RealtimeService Kotlin (Background Service)**
   - ✅ Foreground service con polling ogni N secondi
   - ✅ Parsing JSON trip data da API
   - ✅ Calcolo nextIndex con 4-step fallback logic
   - ✅ Delay normalization (seconds → minutes con floor division)
   - ✅ State fingerprint con 7 campi (nextStop, eventType, delay, remaining, etc.)
   - ✅ Selective notification update (solo quando lo stato cambia)
   - ✅ **Logging dettagliato aggiunto v3** per debugging

3. **Dart ↔ Kotlin Wiring**
   - ✅ MethodChannel bridge per startMonitoring
   - ✅ Passaggio di `arrivalNoticeMinutes` (preavviso)
   - ✅ Passaggio di `destinationStop` per monitoraggio selettivo

4. **UI Settings**
   - ✅ Preavviso slider (5-20 minuti) in settings_screen.dart
   - ✅ Persistenza in SharedPreferences
   - ✅ Lettura dall'app al lancio del monitoring

5. **Delay Calculation**
   - ✅ Normalizzazione a livello trip (delayMinutes)
   - ✅ Normalizzazione a livello stop (arrivalDelay, departureDelay)
   - ✅ Fallback: estimated - scheduled
   - ✅ Floor division per evitare +1/-1 artifacts

### 🟡 In Progress / Parzialmente Completo

1. **Dart notification_manager_provider.dart**
   - 🟡 Partial implementation di body construction
   - ⏳ **TODO:** Replicare completamente la logica di train_details_sheet.dart
   - ⏳ **TODO:** Aggiungere _ActualTime model
   - ⏳ **TODO:** Aggiungere _stopActual helper
   - ⏳ **TODO:** Full stopStates construction
   - ⏳ **TODO:** eventType discrimination (arrival vs departure)

2. **Device Testing**
   - ⏳ **TODO:** Test end-to-end su device con logcat attivo
   - ⏳ **TODO:** Verificare se le notifiche si aggiornano in tempo reale
   - ⏳ **TODO:** Verificare se il server fornisce dati aggiornati

3. **Performance**
   - ⏳ **TODO:** Verificare che il polling interval sia rispettato
   - ⏳ **TODO:** Verificare che non ci sia caching involontario dal server

### ❌ Non Implementato
1. Proximity notification per arrivare a destinazione (parzialmente implementato)
2. Multi-language support nel body notifiche
3. Vibrazione/suono personalizzato per notifiche
4. Swipe-to-remove notifiche con azione "remove monitoring"

---

## Implementazione Logging v3

### File Modificato
- `android/app/src/main/kotlin/com/example/bc_transporter_mobile/RealtimeService.kt`

### Log Aggiunti

#### 1. Fetch Data Log
```kotlin
Log.d("RealtimeService", "Trip $tId fetched JSON: $jsonTrunc")
Log.d("RealtimeService", "Trip $tId: body same as cached (no changes from server)")
// o
Log.d("RealtimeService", "Trip $tId: body differs from cached")
```

#### 2. State Fingerprint Log
```kotlin
Log.d("RealtimeService", "Trip $tId FIRST FETCH → will notify")
// o
Log.d("RealtimeService", "Trip $tId STATE CHANGED:\n  PREV: $prevState\n  NEW: $newState")
// o
Log.d("RealtimeService", "Trip $tId state unchanged → NO notify (data is same as last fetch)")
```

#### 3. Notification Push Log
```kotlin
Log.d("RealtimeService", ">>> SENDING NOTIFICATION for Trip $tId: nextStop='$nextStop' delay=...min eventType=$nextEventType remaining=$remaining")
```

#### 4. Parsed Data Debug Log
```kotlin
Log.d("RealtimeService", "Trip parsed: id=$tId title='...' nextStop='...' lastPassed='...' delay=... remaining=... ...")
Log.d("RealtimeService", "Trip delays debug: nextDelaySeconds=... delayForNotifySeconds=... tripDelaySeconds=... effective=... nextArrival=...")
```

### Utilizzo
Vedi `NOTIFICHE_DEBUG.md` per istruzioni complete su come usare i log.

---

## Root Cause Analysis (Ipotesi)

### Ipotesi 1: Server Congelato
**Sintomi:**
- `body same as cached` appare per tutto il polling
- Lo stato rimane identico

**Se questo è il caso:**
- Non è un bug dell'app
- Il server non sta aggiornando i dati
- Soluzione: Aspetta che il server si aggiorni

### Ipotesi 2: Dati Aggiornati ma Notifiche Non Spinte
**Sintomi:**
- `body differs from cached` appare
- Ma `>>> SENDING NOTIFICATION` non appare
- State fingerprint rimane uguale

**Se questo è il caso:**
- Il JSON cambia (timestamp aggiornati) ma il treno rimane nello stesso "stato"
- Questo è CORRETTO behavior (evita spam)
- Se vuoi più frequenza, diminuisci `arrivalNoticeMinutes`

### Ipotesi 3: Notifiche Spinte ma Non Visibili
**Sintomi:**
- `>>> SENDING NOTIFICATION` appare nei log
- Ma la notifica non si aggiorna nel device

**Se questo è il caso:**
- Possibile bug nel rendering delle notifiche Android
- Possibile che il device abbia disabilitato le notifiche
- Possibile "Risparmio batteria" che blocca le notifiche

---

## Come Procedere

### Fase 1: Test di Debugging (ADESSO)
1. Build app
2. Esegui su device
3. Apri Logcat
4. Filtra per `RealtimeService`
5. Avvia monitoraggio di un treno
6. Guarda i log per 60-120 secondi
7. Salva i log

### Fase 2: Analisi
1. Leggi i log
2. Identifica quale ipotesi si applica
3. Definisci il prossimo step

### Fase 3: Risoluzione
Dipende dalla root cause identificata in Fase 2

---

## File di Riferimento

### Per Developer
- `android/app/src/main/kotlin/com/example/bc_transporter_mobile/RealtimeService.kt` - Main service con logging
- `lib/presentation/providers/notification_manager_provider.dart` - Dart side (in progress)
- `lib/features/train/presentation/widgets/train_details_sheet.dart` - Source of truth per logica UI

### Per Test/Debug
- `NOTIFICHE_DEBUG.md` - Guida step-by-step per usare i log
- `NOTIFICHE_LOGGING_SUMMARY.md` - Summary tecnico del logging v3

---

## Metriche di Successo

✅ Una volta implementati e testati:
- [ ] Server fornisce dati aggiornati ogni N secondi
- [ ] State fingerprint cambia quando il treno si muove
- [ ] Notifiche vengono spinte quando lo stato cambia
- [ ] Notifiche rimangono stabili quando lo stato non cambia (no spam)
- [ ] Notifiche mostrano gli stessi dati della UI (coerenza)
- [ ] Logcat mostra flow corretto senza errori

---

**Ultimato:** 2025-01-15
**Prossima Review:** Dopo test con Logcat
**Team:** [Developer]
