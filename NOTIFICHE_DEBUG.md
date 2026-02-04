# Debug Notifiche Treni - Guida Completa

## Problema Identificato
Le notifiche appaiono "congelate" (dati fermi) con:
- prossima fermata che non cambia
- stato attuale sempre uguale
- fermate rimanenti che non cambiano
- delay sempre uguale

## Causa Possibile
1. **Il server non sta fornendo dati aggiornati** (lo stesso JSON viene restituito a ogni fetch)
2. **Le notifiche non vengono spinte** perché lo stato fingerprint rimane identico
3. **L'intervallo di polling è troppo lungo** (il treno si muove velocemente, l'app controlla ogni 30+ sec)

## Come Verificare

### Step 1: Attiva Log Dettagliato
1. Apri Android Studio → Logcat
2. Filtra per: `RealtimeService`
3. Accendi il monitoraggio notifiche treno

### Step 2: Guarda i Log

**Cerca questi log ogni volta che il polling fetch i dati:**

```
Trip $tId fetched JSON: { ... }    ← mostra il JSON dal server
```

**Se vedi:**
- `Trip $tId: body same as cached` → **Il server sta inviando LO STESSO JSON**
- `Trip $tId: body differs from cached` → **Il server ha aggiornato il JSON**

### Step 3: Guarda se le Notifiche Cambiano

```
>>> SENDING NOTIFICATION for Trip $tId: nextStop='...' delay=...min
```

- Se non vedi questo log = **lo stato non è cambiato**
- Se vedi questo log ma la notifica non si aggiorna = **bug nel display**

### Step 4: Controlla lo State Fingerprint

```
Trip $tId STATE CHANGED:
  PREV: {...}
  NEW: {...}
```

Confronta `nextStop`, `delay`, `remaining` tra PREV e NEW:
- Se cambiano = **il calcolo è giusto, il server fornisce dati nuovi**
- Se rimangono uguali = **il server sta inviando lo stesso JSON**

---

## Come Leggere i Log

### Scenario 1: Server Fornisce Dati Uguali (Congelato dal Server)
```
Trip IC607 fetched JSON: {...}
Trip IC607: body same as cached (no changes from server)
Trip IC607 state unchanged → NO notify (data is same as last fetch)
```

**Azione:** Non è colpa dell'app. Il server non ha dati aggiornati. Prova:
- Aspetta 2-3 minuti che il server si aggiorni
- Ricarca la pagina web per vedere se il server fornisce dati nuovi
- Contatta il provider (Trenitalia, ecc.)

### Scenario 2: Server Fornisce Dati Nuovi Ma Lo Stato Rimane Uguale
```
Trip IC607 fetched JSON: {...}
Trip IC607: body differs from cached
Trip IC607 STATE UNCHANGED: → NO notify (data is same as last fetch)
```

**Azione:** Il JSON è diverso ma `nextStop`, `delay`, `remaining` rimangono identici. Possibili cause:
- Piccole variazioni nel JSON (timestamp aggiornati ma non stop effettivi)
- Metadata cambiati (lastDetection, ma nessun cambio di stato effettivo)
- Questo è CORRETTO → non spingere 100 notifiche per variazioni insignificanti

### Scenario 3: Server Fornisce Dati Nuovi E Lo Stato Cambia
```
Trip IC607 fetched JSON: {...}
Trip IC607: body differs from cached
Trip IC607 STATE CHANGED:
  PREV: {"nextStop":"Milano","delay":5,...}
  NEW: {"nextStop":"Piacenza","delay":3,...}
>>> SENDING NOTIFICATION for Trip IC607: nextStop='Piacenza' delay=3min
```

**Azione:** PERFETTO! Le notifiche stanno funzionando correttamente. La notifica dovrebbe aggiornarsi nel device.

---

## Come Risolvere

### Se Scenario 1 (Server Congelato)
- ❌ Non modificare app/codice
- ✅ Aspetta che il server si aggiorni
- ✅ Testa con URL diretta tramite browser per verificare il server

### Se Scenario 2 (Piccole Variazioni)
- ✅ COMPORTAMENTO CORRETTO → le notifiche non vengono spinte per ogni micro-variazione
- Se desideri più frequenza, diminuisci `arrivalNoticeMinutes` nelle impostazioni (es. da 10 a 5)

### Se Scenario 3 (Tutto Perfetto)
- ✅ Le notifiche dovrebbero aggiornarsi in tempo reale
- Se non vedi l'aggiornamento nel device, il problema è nel sistema di notifiche Android (non l'app)

---

## Log Chiave da Cercare

| Log | Significato |
|-----|-------------|
| `Trip X fetched JSON:` | Nuovo fetch dal server |
| `body same as cached` | Server non ha cambiato nulla |
| `body differs from cached` | Server ha nuovi dati |
| `STATE CHANGED` | Lo stato effettivo del treno è cambiato |
| `state unchanged → NO notify` | Dati non cambiano, non spingere notifica |
| `>>> SENDING NOTIFICATION` | **Notifica spinta al device** |
| `FIRST FETCH` | Prima volta che vediamo questo treno |

---

## Test Rapido

1. Apri app → seleziona un treno → attiva monitoraggio
2. Apri Logcat → filtra `RealtimeService`
3. Guarda per ~60 secondi
4. Doppio-check: il log `>>> SENDING NOTIFICATION` appare almeno una volta?
   - **SÌ** → notifiche funzionano
   - **NO** → possibile server congelato

---

## Informazioni per il Developer

Se il problema persiste, raccogli questi log:
1. Cattura da Logcat (60-120 sec di polling)
2. Salva il JSON fetched (primo fetch)
3. Salva lo state fingerprint (PREV e NEW)
4. Specifica: quale treno? quale provider (IT/DE)?
