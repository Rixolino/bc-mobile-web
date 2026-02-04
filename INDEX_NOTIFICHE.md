# 📚 Notifiche Treni v3 - Indice Documentazione

## 🎯 Start Here

Se non sai da dove cominciare, leggi in questo ordine:

1. **`QUICK_START_NOTIFICHE.md`** (⏱️ 2 minuti)
   - Overview veloce
   - 3 scenari principali
   - Prossimi step

2. **`NOTIFICHE_DEBUG.md`** (⏱️ 10 minuti)
   - Guida step-by-step
   - Come aprire Logcat
   - Come interpretare i log

3. **Esegui il test** (⏱️ 10-15 minuti)
   - Segui `CHECKLIST_PRETEST.md`
   - Cattura log con `capture_logs.bat`
   - Osserva quale scenario corrisponde

---

## 📖 Per Ruolo

### 🔴 Se Sei l'Utente (Non Tecnico)
Leggi in ordine:
1. `QUICK_START_NOTIFICHE.md` (come fare il test)
2. `NOTIFICHE_DEBUG.md` (come interpretare i risultati)

### 🟠 Se Sei il QA/Tester
Leggi in ordine:
1. `QUICK_START_NOTIFICHE.md`
2. `CHECKLIST_PRETEST.md` (vedi cosa verificare)
3. `NOTIFICHE_DEBUG.md` (come raccogliere i dati)
4. `capture_logs.bat` (per raccogliere automaticamente)

### 🟡 Se Sei il Developer
Leggi in ordine:
1. `TECHNICAL_REPORT_v3.md` (technical overview)
2. `NOTIFICHE_LOGGING_SUMMARY.md` (technical deep-dive)
3. `STATUS_NOTIFICHE_2025.md` (project status)
4. Codice: `RealtimeService.kt` (linee 228, 380, 950, 1100)

### 🟢 Se Sei il DevOps/Manager
Leggi:
1. `IMPLEMENTATION_SUMMARY_v3.md` (overview globale)
2. `STATUS_NOTIFICHE_2025.md` (metriche e stato)

---

## 📄 Documentazione Completa

### 📋 Guida Utente (Quick & Simple)
| File | Contenuto | Tempo | Utente |
|------|-----------|-------|--------|
| **`QUICK_START_NOTIFICHE.md`** | Guida veloce (2 min) | ⏱️ 2 min | Non-tech |
| **`NOTIFICHE_DEBUG.md`** | Guida completa passo-passo | ⏱️ 10 min | Tester |
| **`CHECKLIST_PRETEST.md`** | Checklist di test | ⏱️ 5 min | QA |

### 🔧 Documentazione Tecnica (Technical)
| File | Contenuto | Tempo | Utente |
|------|-----------|-------|--------|
| **`TECHNICAL_REPORT_v3.md`** | Report tecnico completo | ⏱️ 15 min | Developer |
| **`NOTIFICHE_LOGGING_SUMMARY.md`** | Summary tecnico logging | ⏱️ 10 min | Developer |
| **`STATUS_NOTIFICHE_2025.md`** | Status e metriche progetto | ⏱️ 10 min | Manager |
| **`IMPLEMENTATION_SUMMARY_v3.md`** | Overview implementazione | ⏱️ 10 min | Manager |

### 🛠️ Tools & Scripts
| File | Uso | Platform |
|------|-----|----------|
| **`capture_logs.bat`** | Script cattura log automatica | Windows |

---

## 🚀 Step-by-Step Test

### Step 1: Preparazione (2 minuti)
```
1. Build app: flutter clean && flutter pub get && flutter run
2. Connetti device Android via USB
3. Apri Android Studio
```

### Step 2: Avvio Logcat (1 minuto)
```
Android Studio → View → Tool Windows → Logcat
Filtra: RealtimeService
```

### Step 3: Test (10-15 minuti)
```
1. Apri app
2. Vai su dettaglio treno
3. Premi "Monitor Train"
4. Osserva Logcat per 2-3 minuti
```

### Step 4: Analisi (5 minuti)
```
1. Confronta i log con i 3 scenari in QUICK_START_NOTIFICHE.md
2. Identifica quale scenario corrisponde
3. Scrivi il risultato
```

---

## 🎯 3 Scenari Principali

### ✅ Scenario 1: Server OK (Notifiche Funzionano)
```
Cosa vedi: "body differs" + "STATE CHANGED" + ">>> SENDING NOTIFICATION"
Significa: Notifiche funzionano perfettamente
Azione: Deploy, problema risolto ✨
```

### ⚠️ Scenario 2: Server Congelato
```
Cosa vedi: "body IDENTICAL" ripetuto per tutta la durata
Significa: Server non aggiorna dati, non è bug app
Azione: Aspetta server aggiorna, oppure contatta provider
```

### 🟡 Scenario 3: Cambio Minore (Normale)
```
Cosa vedi: "body differs" ma "state unchanged → NO notify"
Significa: JSON cambia (timestamp) ma stato treno rimane uguale
Azione: Comportamento corretto, niente bug. Deploy.
```

---

## 📊 Key Log Messages

```
═══ POLLING ITERATION START ═══     ← Inizio ciclo polling
Trip X fetched JSON (Y chars)        ← JSON fetched da server
body IDENTICAL / differs [±Z chars]  ← Se server ha aggiornato
Trip parsed: ...                     ← Dati parsati dal JSON
>>> SENDING NOTIFICATION             ← NOTIFICA SPINTA ✅
STATE CHANGED: PREV/NEW              ← Stato cambiato
state unchanged → NO notify          ← Niente cambia (avoid spam)
```

---

## ✅ Success Criteria

Implementazione è riuscita quando:
- ✅ Logging è presente e funzionante
- ✅ Logcat mostra almeno uno dei 3 scenari
- ✅ Puoi discriminare tra app-side e server-side issues
- ✅ Notifiche vengono spinte correttamente

---

## ⏭️ Prossimi Step (Dopo Test)

### Se Scenario ✅ OK
```
1. ✅ Notifiche funzionano
2. ✅ Pronto per production
3. → Implementare train_details_sheet.dart replication (Fase 2)
```

### Se Scenario ⚠️ Server Congelato
```
1. 🕐 Aspetta server aggiorna
2. 🧪 Verifica API da browser
3. 📞 Contatta provider
```

### Se Scenario 🟡 Normale
```
1. ✅ Comportamento corretto
2. ✅ Niente bug
3. → Deploy
```

---

## 📞 FAQ

### Q: Dove trovo i log?
**A:** Android Studio → Logcat (filtra: `RealtimeService`)

### Q: Perché le notifiche non vengono spinte?
**A:** Vedi i 3 scenari. Se vedi "STATE CHANGED" ma non "SENDING NOTIFICATION", c'è un bug.

### Q: Quanto deve durare il test?
**A:** 120 secondi (2 minuti) minimo per vedere almeno 2-3 cicli di polling.

### Q: Che intervallo è il polling?
**A:** Default 30 secondi. Vedi `actual interval` nel log `POLLING ITERATION START`.

### Q: Posso catturare i log automaticamente?
**A:** Sì, usa `capture_logs.bat` (Windows only).

### Q: Cosa fare se non vedo NESSUN log?
**A:** Possibile bug nel wiring Dart↔Kotlin. Verifica scheduleTrainsWorker() in MainActivity.kt.

---

## 🔍 Come Cercare nei Log

### Per trovare solo SEND_NOTIFICATION
```bash
grep ">>> SENDING NOTIFICATION" logfile.txt
```

### Per contare quante volte server aggiorna
```bash
grep "body differs" logfile.txt | wc -l
```

### Per contare quante notifiche spinte
```bash
grep ">>> SENDING NOTIFICATION" logfile.txt | wc -l
```

### Per vedere tutti i STATE CHANGED
```bash
grep "STATE CHANGED" logfile.txt -A2
```

---

## 🎓 Learning Path

```
Beginner:
  → QUICK_START_NOTIFICHE.md
  → NOTIFICHE_DEBUG.md
  → Esegui test

Intermediate:
  → CHECKLIST_PRETEST.md
  → NOTIFICHE_LOGGING_SUMMARY.md
  → Analizza risultati

Advanced:
  → TECHNICAL_REPORT_v3.md
  → RealtimeService.kt codice
  → Modifica logging
```

---

## 📋 Checklist Pre-Test

- [ ] App compilata
- [ ] Device collegato
- [ ] Logcat funzionante
- [ ] Filtro `RealtimeService` attivato
- [ ] Treno selezionato
- [ ] Monitor Train button premuto
- [ ] Cronometro partito (120 sec)
- [ ] Log raccolti

---

## 🚀 When to Deploy

✅ Ready for production when:
- [x] Logging implementato
- [x] Documentazione completata
- [ ] Test su device eseguito (NEXT)
- [ ] Risultati analizzati (NEXT)
- [ ] Scenario identificato (NEXT)

---

## 📞 Support Contacts

Se hai dubbi:
1. Controlla FAG qui sopra
2. Leggi NOTIFICHE_DEBUG.md completamente
3. Guarda i log per 5 minuti
4. Confronta con gli scenari in QUICK_START_NOTIFICHE.md

---

## 📅 Timeline

| Milestone | Status | Data |
|-----------|--------|------|
| Logging Implementation | ✅ DONE | 2025-01-15 |
| Documentation Creation | ✅ DONE | 2025-01-15 |
| Ready for Testing | ⏳ NEXT | 2025-01-15 |
| Test Execution | ⏳ TBD | 2025-01-?? |
| Root Cause Identification | ⏳ TBD | 2025-01-?? |
| Fase 2 Implementation | ⏳ TBD | 2025-01-?? |

---

## 📚 File List

```
mobile_app/
├── QUICK_START_NOTIFICHE.md           ⭐ START HERE (2 min)
├── NOTIFICHE_DEBUG.md                 📖 Guida completa (10 min)
├── NOTIFICHE_LOGGING_SUMMARY.md       🔧 Technical (10 min)
├── TECHNICAL_REPORT_v3.md             📊 Report (15 min)
├── STATUS_NOTIFICHE_2025.md           📈 Status (10 min)
├── IMPLEMENTATION_SUMMARY_v3.md       📋 Overview (10 min)
├── CHECKLIST_PRETEST.md               ✅ Test checklist (5 min)
├── capture_logs.bat                   🛠️ Script (Windows)
├── NOTIFICHE_DEBUG.md                 (duplicate link, see above)
│
├── android/app/src/main/kotlin/com/example/bc_transporter_mobile/
│   └── RealtimeService.kt             🔴 Modified file
│
└── README.md                          📄 Project readme
```

---

**Generated:** 2025-01-15
**Status:** ✅ Complete Documentation Package
**Next Step:** Follow QUICK_START_NOTIFICHE.md to test
