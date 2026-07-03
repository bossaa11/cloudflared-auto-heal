@echo off
set TASKNAME=Cloudflare Tunnel Recovery
set SCRIPT=C:\Scripts\cf-recovery.ps1

schtasks /delete /tn "%TASKNAME%" /f >nul 2>&1

schtasks /create ^
/tn "%TASKNAME%" ^
/sc ONSTART ^
/ru SYSTEM ^
/rl HIGHEST ^
/tr "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"%SCRIPT%\"" ^
/f

echo.
echo Task Scheduler Task Created Successfully.
echo Task Name: %TASKNAME%
echo.
pause