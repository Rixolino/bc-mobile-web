# Summary Miglioramenti Notifiche Treni v3

## Problema Principale
Le notifiche treni apparivano "congelate" con:
- Prossima fermata che non cambia
- Ritardo che rimane lo stesso
- Fermate rimanenti congelate
- Nessun aggiornamento in tempo reale

## Root Cause Identificata
Il problema potrebbe essere uno di questi 3:
1. **Server congelato** (non invia dati aggiornati)
2. **Notifiche non vengono spinte** (lo stato rimane identico)
3. **Interval di polling troppo lungo** (treno si muove velocemente, app controlla ogni 30+ sec)

## Soluzione Implementata: Logging Dettagliato

### Modifiche al Kotlin (RealtimeService.kt)

#### 1. Log Fetch Dati dal Server
```kotlin
Log.d("RealtimeService", "Trip $tId fetched JSON: $jsonTrunc")
if (previousBody == body) {
    Log.d("RealtimeService", "Trip $tId: body same as cached (no changes from server)")
} else {
    Log.d("RealtimeService", "Trip $tId: body differs from cached")
}
```

**Cosa mostra:**
- Se il JSON dal server è IDENTICO al precedente
- Se il server ha AGGIORNATO i dati

#### 2. Log State Fingerprint
```kotlin
if (prevState == null) {
    Log.d("RealtimeService", "Trip $tId FIRST FETCH → will notify")
} else if (prevState != newState) {
    Log.d("RealtimeService", "Trip $tId STATE CHANGED:\n  PREV: $prevState\n  NEW: $newState")
} else {
    Log.d("RealtimeService", "Trip $tId state unchanged → NO notify (data is same as last fetch)")
}
```

**Cosa mostra:**
- Lo state fingerprint precedente (nextStop, delay, remaining, etc.)
- Lo state fingerprint nuovo
- Quale campo è cambiato

#### 3. Log Notifica Spinta
```kotlin
if (shouldNotify) {
    Log.d("RealtimeService", ">>> SENDING NOTIFICATION for Trip $tId: nextStop='$nextStop' delay=${nextDelaySeconds?.div(60) ?: delaySeconds/60}min eventType=$nextEventType remaining=$remaining")
}
```

**Cosa mostra:**
- **QUANDO** la notifica viene spinta
- Quali sono i nuovi valori (next stop, delay, remaining)
- Event type (arrival vs departure)

#### 4. Log Dati Parsati
```kotlin
Log.d("RealtimeService", "Trip parsed: id=$tId title='${title}' nextStop='$nextStop' lastPassed='$lastPassed' delay=$delayForStateMinutes remaining=$remaining notifyMode=$notifyMode destination='$destinationStop'")
Log.d("RealtimeService", "Trip delays debug: nextDelaySeconds=${nextDelaySeconds ?: "null"} delayForNotifySeconds=${delayForNotifySeconds ?: "null"} tripDelaySeconds=${delaySeconds} effective=${effectiveForNotify?.toString() ?: "null"} nextArrival=${nextArrivalInstant?.toString() ?: "null"}")
```

**Cosa mostra:**
- Tutti i dati parsati dal JSON (per verificare che siano corretti)
- Quali fonti di delay vengono usate (nextDelaySeconds vs tripDelaySeconds)
- Instant effettivo calcolato

## Come Usare i Log

### Step 1: Apri Logcat
Android Studio → View → Tool Windows → Logcat

### Step 2: Filtra per `RealtimeService`
In Logcat, digita nel filtro: `RealtimeService`

### Step 3: Attiva il Monitoraggio Notifiche
Nell'app:
1. Vai a Train Details
2. Premi il pulsante "Monitor Train"
3. Torna alla home

### Step 4: Guarda i Log per ~60-120 Secondi

**Dovresti vedere dei log come:**
```
D RealtimeService: Fetching trip IC607 -> https://prod.cuzimmartin.dev/api/it/trip?tripId=IC607
D RealtimeService: Trip IC607 fetched JSON: {...JSON truncato a 1000 chars...}
D RealtimeService: Trip IC607: body differs from cached
D RealtimeService: Trip parsed: id=IC607 title='IC 607 (Milano Porta Garibaldi → Lecce)' nextStop='Piacenza' lastPassed='Milano Porta Garibaldi' delay=5 remaining=12 notifyMode=general ...
D RealtimeService: Trip delays debug: nextDelaySeconds=300 delayForNotifySeconds=null tripDelaySeconds=300 effective=2024-01-15T14:35:00Z nextArrival=2024-01-15T14:35:00Z
D RealtimeService: >>> SENDING NOTIFICATION for Trip IC607: nextStop='Piacenza' delay=5min eventType=arrival remaining=12
```

## Scenari Possibili e Cosa Significano

### Scenario 1: Server Non Aggiorna Dati
```
Trip IC607: body same as cached (no changes from server)
Trip IC607 state unchanged → NO notify (data is same as last fetch)
```
→ **Il server non sta fornendo dati nuovi. Non è colpa dell'app.**
→ Soluzione: Aspetta che il server si aggiorni, oppure il treno è finito.

### Scenario 2: Piccole Variazioni nel JSON
```
Trip IC607: body differs from cached
Trip IC607 state unchanged → NO notify (data is same as last fetch)
```
→ **Il JSON è cambiato (es. timestamp aggiornato) ma il treno rimane nello stesso "stato".**
→ Questo è CORRETTO e DESIDERATO (evita spam di notifiche).

### Scenario 3: Treno Avanza (Perfetto!)
```
Trip IC607: body differs from cached
Trip IC607 STATE CHANGED:
  PREV: {"nextStop":"Milano","delay":5,...}
  NEW: {"nextStop":"Piacenza","delay":3,...}
>>> SENDING NOTIFICATION for Trip IC607: nextStop='Piacenza' delay=3min eventType=arrival remaining=11
```
→ **PERFETTO! La notifica viene spinta.**
→ Verifica che il device riceva la notifica.

## Checklist di Debug

- [ ] Apri Logcat, filtra per `RealtimeService`
- [ ] Avvia il monitoraggio di un treno
- [ ] Guarda i log per 60-120 secondi
- [ ] Cerchi: `body differs from cached` appare?
  - Sì → il server sta aggiornando
  - No → il server è congelato
- [ ] Cerchi: `STATE CHANGED` appare?
  - Sì → la notifica dovrebbe essere spinta
  - No → il treno rimane nello stesso stato
- [ ] Cerchi: `>>> SENDING NOTIFICATION` appare?
  - Sì → l'app sta tentando di spingere la notifica
  - No → nessuna notifica spinta (data è ancora la stessa)

## Prossimi Passi Consigliati

1. **Esegui il test dei log** seguendo le istruzioni qui
2. **Cattura i log** di 60-120 sec e salvali
3. **Se il server è congelato:**
   - Test manuale via browser della URL dell'API
   - Controlla se altre app vedono i dati aggiornati
4. **Se le notifiche non vengono spinte:**
   - Verifica che il device non abbia disabilitato le notifiche
   - Controlla le impostazioni di "Risparmio batteria"
5. **Se tutto sembra perfetto:**
   - Verifica che il display della notifica si aggiorna correttamente
   - Possibile bug nel sistema di rendering delle notifiche Android

---

**Data Implementazione:** 2025-01-15
**Scope:** Kotlin RealtimeService.kt - Logging completo per debugging notifiche treni
**Prossima Fase:** Test on device con Logcat attivo per identificare root cause esatta
