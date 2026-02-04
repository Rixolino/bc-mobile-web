# 🚀 Notifiche Treni v3 - Guida Veloce (2 min)

## Cosa è Stato Fatto

Abbiamo aggiunto **logging super dettagliato** nel servizio Android per capire ESATTAMENTE dove il problema si trova:

1. ✅ Log mostra SE il server sta fornendo dati nuovi
2. ✅ Log mostra SE lo stato del treno sta cambiando
3. ✅ Log mostra SE le notifiche vengono spinte
4. ✅ Log mostra QUANTO è lungo l'intervallo tra i polling

---

## Come Testare (3 Passi)

### Step 1: Apri i Log
```
Android Studio → View → Tool Windows → Logcat
```

Nel filtro scrivi:
```
RealtimeService
```

### Step 2: Avvia il Monitoraggio
Nell'app:
1. Vai su un dettaglio di un treno (es. IC 607)
2. Premi il bottone **"Monitor Train"**
3. Torna alla home

### Step 3: Osserva per 2 Minuti
Dovresti vedere log come:
```
═══ POLLING ITERATION START ═══ (actual interval: 30s, target: 30s)
Trip IC607 fetched JSON (8234 chars): {...}
Trip IC607: body IDENTICAL to cached (8234 chars, no changes from server)
Trip IC607 state unchanged → NO notify (data is same as last fetch)
```

---

## 3 Scenari Possibili

### ✅ Server OK (Notifiche Funzionano)
```
Trip IC607: body differs [PREV: 8200 chars → NEW: 8350 chars (+150 chars)]
Trip IC607 STATE CHANGED:
  PREV: {"nextStop":"Milano","delay":5,...}
  NEW: {"nextStop":"Piacenza","delay":3,...}
>>> SENDING NOTIFICATION for Trip IC607: nextStop='Piacenza' delay=3min
```
✔️ **Perfetto!** Le notifiche stanno funzionando.

---

### ⚠️ Server Congelato (Non Colpa dell'App)
```
Trip IC607: body IDENTICAL to cached (8234 chars, no changes from server)
Trip IC607: body IDENTICAL to cached (8234 chars, no changes from server)
Trip IC607: body IDENTICAL to cached (8234 chars, no changes from server)
```
❌ **Il server non sta fornendo dati nuovi.** Non è un bug dell'app.

**Cosa Fare:**
- Aspetta 2-3 minuti
- Test manuale dell'API dal browser
- Contatta il provider (Trenitalia, ecc.)

---

### 🟡 Cambio Minore (Comportamento Corretto)
```
Trip IC607: body differs [PREV: 8200 chars → NEW: 8210 chars (+10 chars)]
Trip IC607 state unchanged → NO notify (data is same as last fetch)
```
✔️ **Perfetto!** Piccole variazioni nel JSON (es. timestamp aggiornati) ma lo stato del treno rimane lo stesso.

**Questo è CORRETTO** perché evita di spingere 100 notifiche inutili.

---

## Key Log Messages

| Log | Significa |
|-----|-----------|
| `POLLING ITERATION START` | Inizio di un ciclo di polling (ogni N secondi) |
| `fetched JSON (X chars)` | JSON scaricato dal server (X caratteri) |
| `IDENTICAL to cached` | Server non ha cambiato nulla |
| `differs [PREV: X → NEW: Y]` | Server ha aggiornato il JSON |
| `STATE CHANGED` | Il treno si è spostato (next stop, delay, etc. sono cambiati) |
| `>>> SENDING NOTIFICATION` | **La notifica viene spinta al device** |
| `state unchanged → NO notify` | Dati non cambiano, non spingere notifica (CORRETTO) |

---

## Prossimi Step

1. **Se vedi Scenario ✅:** Il problema è RISOLTO ✨
2. **Se vedi Scenario ⚠️:** Aspetta che il server si aggiorni 🕐
3. **Se vedi Scenario 🟡:** Comportamento CORRETTO, niente da fare ✔️
4. **Se non vedi NESSUN log:** Possibile bug nel wiring Dart↔Kotlin (contatta dev)

---

## File di Riferimento

- `NOTIFICHE_DEBUG.md` - Guida dettagliata
- `STATUS_NOTIFICHE_2025.md` - Report tecnico
- `CHECKLIST_PRETEST.md` - Checklist completa

---

**Tempo Lettura:** 2 minuti ⏱️
**Tempo Test:** 5-10 minuti 🧪
**Status:** ✅ Pronto per il test
