@echo off
setlocal
cd /d "%~dp0"
echo CRISIS startet lokal auf http://127.0.0.1:4173
echo Dieses Fenster waehrend der Nutzung geoeffnet lassen.
echo.
where node >nul 2>nul
if not errorlevel 1 (
  node -e "process.exit(Number(process.versions.node.split('.')[0]) >= 22 ? 0 : 1)" >nul 2>nul
  if not errorlevel 1 (
    echo Node.js gefunden. Marktdatenabruf ist verfuegbar.
    node tools\server.mjs
    goto finished
  )
)
where python >nul 2>nul
if not errorlevel 1 (
  python -c "import sys; sys.exit(0 if sys.version_info >= (3,8) else 1)" >nul 2>nul
  if not errorlevel 1 (
    python tools\start-web.py
    goto finished
  )
)
where py >nul 2>nul
if not errorlevel 1 (
  py -3 tools\start-web.py
  goto finished
)
echo Python wurde nicht gefunden. Python 3.8+ oder Node.js 22+ muss ausfuehrbar sein.
echo Python kann fuer den eigenen Benutzer ohne Administratorrechte installiert werden.
:finished
echo.
echo Der Server wurde beendet. Fehlermeldungen stehen oberhalb dieser Zeile.
pause
