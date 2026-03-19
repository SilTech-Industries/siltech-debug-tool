@echo off
setlocal enabledelayedexpansion
title SilTech Debug Toolkit
color 0A

:MENU
cls
echo.
echo   ====================================================
echo    SilTech Industries - Debug Toolkit
echo    Field Service Tool (Zero-Install, Windows 10/11)
echo   ====================================================
echo.

:: Auto-detect COM port
set COMPORT=
for /f "tokens=*" %%a in ('powershell -NoProfile -Command "Get-CimInstance Win32_PnPEntity | Where-Object { $_.Name -match 'CH340|CP210|FTDI|USB.Serial|Silicon Labs' -and $_.Name -match 'COM\d+' } | ForEach-Object { if ($_.Name -match '(COM\d+)') { $Matches[1] } } | Select-Object -First 1"') do set COMPORT=%%a

if "%COMPORT%"=="" (
    echo   [!] No USB-TTL adapter detected
) else (
    echo   [USB] Detected: %COMPORT%
)
echo.

:: List available firmware folders
echo   Available Devices:
echo   ------------------
set IDX=0
for /d %%d in (firmware\*) do (
    set /a IDX+=1
    set "DEV_!IDX!=%%~nxd"
    echo     !IDX!. %%~nxd
)
echo.

if %IDX% EQU 0 (
    echo   [ERROR] No firmware found in firmware\ folder!
    echo   Add device folders: firmware\IO_Controller\, firmware\BusLog_4G_v2\, etc.
    echo.
    pause
    goto :EOF
)

echo   Tools:
echo     F. Flash App Only (keeps config)
echo     A. Flash Full (bootloader + partitions + app)
echo     E. Erase Flash (wipe everything)
echo     M. Serial Monitor
echo     I. Device Info (chip ID, MAC, flash size)
echo     Q. Quit
echo.

set /p CHOICE="   Select: "

:: Strip whitespace from input
set "CHOICE=%CHOICE: =%"

if /i "%CHOICE%"=="Q" goto :EOF
if /i "%CHOICE%"=="E" goto :ERASE
if /i "%CHOICE%"=="M" goto :MONITOR
if /i "%CHOICE%"=="I" goto :DEVICEINFO
if /i "%CHOICE%"=="F" goto :SELECT_DEVICE_APP
if /i "%CHOICE%"=="A" goto :SELECT_DEVICE_FULL

echo   [ERROR] Invalid choice: "%CHOICE%"
timeout /t 2 >nul
goto :MENU

:SELECT_DEVICE_APP
set FLASH_MODE=APP
goto :SELECT_DEVICE

:SELECT_DEVICE_FULL
set FLASH_MODE=FULL
goto :SELECT_DEVICE

:SELECT_DEVICE
echo.
if %IDX% EQU 1 (
    set DEVNAME=!DEV_1!
    echo   Auto-selected: !DEVNAME!
) else (
    set /p DEVNUM="   Select device number: "
    set DEVNAME=!DEV_%DEVNUM%!
    if "!DEVNAME!"=="" (
        echo   [ERROR] Invalid selection.
        timeout /t 2 >nul
        goto :MENU
    )
)

:: Check firmware exists
if not exist "firmware\!DEVNAME!\firmware.bin" (
    echo   [ERROR] firmware\!DEVNAME!\firmware.bin not found!
    pause
    goto :MENU
)

if /i "%FLASH_MODE%"=="FULL" goto :FLASH_FULL
goto :FLASH_APP

:CHECK_COM
if "%COMPORT%"=="" (
    echo.
    echo   [ERROR] No USB-TTL adapter found! Plug in and try again.
    pause
    goto :MENU
)
goto :EOF

:FLASH_APP
call :CHECK_COM
echo.
echo   Flashing !DEVNAME! (app only) on %COMPORT%...
echo.

esptool.exe --port %COMPORT% --baud 460800 --chip esp32 ^
  write-flash 0x10000 firmware\!DEVNAME!\firmware.bin

echo.
if %ERRORLEVEL% EQU 0 (
    echo   [OK] Flash complete!
    echo.
    set /p STARTMON="   Start monitor? (Y/n): "
    if /i not "!STARTMON!"=="n" (
        powershell -ExecutionPolicy Bypass -File "%~dp0monitor.ps1"
    )
) else (
    echo   [ERROR] Flash failed! Check USB connection.
    pause
)
goto :MENU

:FLASH_FULL
call :CHECK_COM
echo.
echo   ================================================
echo    WARNING: Full flash will ERASE device config!
echo    WiFi settings, timers, credentials — ALL GONE.
echo   ================================================
echo.
echo   Flashing !DEVNAME! on %COMPORT%...
echo.

:: Check if bootloader and partitions exist
if not exist "firmware\!DEVNAME!\bootloader.bin" (
    echo   [WARN] No bootloader.bin — flashing app only at 0x10000
    esptool.exe --port %COMPORT% --baud 460800 --chip esp32 ^
      write-flash 0x10000 firmware\!DEVNAME!\firmware.bin
) else (
    pause
    esptool.exe --port %COMPORT% --baud 460800 --chip esp32 ^
      write-flash --flash-mode dio --flash-size 4MB ^
      0x1000  firmware\!DEVNAME!\bootloader.bin ^
      0x8000  firmware\!DEVNAME!\partitions.bin ^
      0x10000 firmware\!DEVNAME!\firmware.bin
)

echo.
if %ERRORLEVEL% EQU 0 (
    echo   [OK] Flash complete!
    echo.
    set /p STARTMON="   Start monitor? (Y/n): "
    if /i not "!STARTMON!"=="n" (
        powershell -ExecutionPolicy Bypass -File "%~dp0monitor.ps1"
    )
) else (
    echo   [ERROR] Flash failed! Check USB connection.
    pause
)
goto :MENU

:ERASE
call :CHECK_COM
echo.
echo   ================================================
echo    WARNING: This will ERASE EVERYTHING!
echo    Only use if device is bricked.
echo   ================================================
echo.
set /p CONFIRM="   Type YES to confirm: "
if /i not "%CONFIRM%"=="YES" goto :MENU

esptool.exe --port %COMPORT% --chip esp32 erase-flash

echo.
if %ERRORLEVEL% EQU 0 (
    echo   [OK] Flash erased. Now use Full Flash to restore.
) else (
    echo   [ERROR] Erase failed!
)
pause
goto :MENU

:MONITOR
call :CHECK_COM
echo.
echo   Starting serial monitor on %COMPORT%...
echo   (Press Ctrl+C to stop)
echo.
powershell -ExecutionPolicy Bypass -File "%~dp0monitor.ps1"
goto :MENU

:DEVICEINFO
call :CHECK_COM
echo.
echo   Reading device info from %COMPORT%...
echo.
esptool.exe --port %COMPORT% --chip esp32 chip-id
echo.
esptool.exe --port %COMPORT% --chip esp32 flash-id
echo.
pause
goto :MENU
