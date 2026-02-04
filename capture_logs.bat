@echo off
REM Script per catturare log RealtimeService da device Android
REM Uso: salva questo file come capture_logs.bat e eseguilo dalla linea di comando

setlocal enabledelayedexpansion

echo.
echo ==========================================
echo CATTURA LOG NOTIFICHE TRENI
echo ==========================================
echo.
echo Questo script catturera i log RealtimeService per 2 minuti
echo Assicurati che il device Android sia collegato e il debug USB abilitato
echo.
pause

echo.
echo [1/3] Pulendo i log precedenti...
adb logcat -c

echo.
echo [2/3] Catturando log per 120 secondi (2 minuti)...
echo Per fermare premere Ctrl+C
echo.

REM Capture per 2 minuti
adb logcat RealtimeService:V *:S > logs_notifiche_%date:~-4%-%date:~-10,2%-%date:~-7,2%_%time:~0,2%-%time:~3,2%-%time:~6,2%.txt 2>&1

timeout /t 120 /nobreak

echo.
echo [3/3] Log salvati in: logs_notifiche_*.txt

echo.
echo ==========================================
echo ANALISI DEI LOG
echo ==========================================
echo.

REM Cerca key messages
for /f "delims=" %%i in ('dir /b logs_notifiche_*.txt ^| findstr /r "^logs_notifiche"') do (
    set logfile=%%i
    echo File log: !logfile!
    echo.
    
    echo --- Occorrenze di "body differs" (server ha aggiornato) ---
    findstr /i "body differs" !logfile! | wc -l
    
    echo --- Occorrenze di "body same as cached" (server congelato) ---
    findstr /i "body same as cached" !logfile! | wc -l
    
    echo --- Occorrenze di "STATE CHANGED" (treno si muove) ---
    findstr /i "STATE CHANGED" !logfile! | wc -l
    
    echo --- Occorrenze di "SENDING NOTIFICATION" (notifica spinta) ---
    findstr /i "SENDING NOTIFICATION" !logfile! | wc -l
)

echo.
echo Apri il file log con un editor di testo per dettagli completi.
echo.
pause
