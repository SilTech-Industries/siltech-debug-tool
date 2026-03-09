@echo off
setlocal enabledelayedexpansion
title SilTech Production Flash Tool
color 0A
mode con: cols=70 lines=40

:: ============================================================
::  SilTech Industries - Production Flash Tool
::  For factory workers: minimal interaction, maximum safety
::  
::  Flow: Select device once → Flash → Monitor → Q → Flash next
::  Just keep pressing ENTER to flash device after device
:: ============================================================

:STARTUP
cls
echo.
echo   ====================================================
echo    SilTech Industries - Production Flash Tool
echo    Factory Floor Edition
echo   ====================================================
echo.

:: ── Auto-detect COM port ────────────────────────────────────
set COMPORT=
for /f "tokens=*" %%a in ('powershell -NoProfile -Command "Get-CimInstance Win32_PnPEntity | Where-Object { $_.Name -match 'CH340|CP210|FTDI|USB.Serial|Silicon Labs' -and $_.Name -match 'COM\d+' } | ForEach-Object { if ($_.Name -match '(COM\d+)') { $Matches[1] } } | Select-Object -First 1"') do set COMPORT=%%a

if "%COMPORT%"=="" (
    echo.
    echo   [ERROR] No USB adapter detected!
    echo   Plug in the CH340/CP2102 cable and try again.
    echo.
    pause
    goto :STARTUP
)
echo   [OK] USB Adapter: %COMPORT%
echo.

:: ── Select Device Type ──────────────────────────────────────
echo   Select Device Type:
echo   -------------------
set IDX=0
for /d %%d in (firmware\*) do (
    set /a IDX+=1
    set "DEV_!IDX!=%%~nxd"
    echo     !IDX!. %%~nxd
)
echo.

if %IDX% EQU 0 (
    echo   [ERROR] No firmware found in firmware\ folder!
    pause
    goto :EOF
)

set /p DEVNUM="   Enter device number: "
set DEVNAME=!DEV_%DEVNUM%!
if "!DEVNAME!"=="" (
    echo   [ERROR] Invalid selection!
    timeout /t 2 >nul
    goto :STARTUP
)

:: Verify firmware files exist
if not exist "firmware\!DEVNAME!\firmware.bin" (
    echo   [ERROR] firmware.bin not found for !DEVNAME!
    pause
    goto :STARTUP
)

:: ── Select Flash Mode ───────────────────────────────────────
echo.
echo   Select Flash Mode:
echo   ------------------
echo     1. Full Flash (new devices - bootloader + partitions + app)
echo     2. App Only   (firmware update - keeps device config)
echo.
set /p FMODE="   Enter mode (1 or 2): "

if "%FMODE%"=="1" (
    set FLASH_TYPE=FULL
    :: Check for bootloader and partitions
    if not exist "firmware\!DEVNAME!\bootloader.bin" (
        echo   [ERROR] bootloader.bin missing for !DEVNAME!
        echo   Cannot do full flash without bootloader.
        pause
        goto :STARTUP
    )
    if not exist "firmware\!DEVNAME!\partitions.bin" (
        echo   [ERROR] partitions.bin missing for !DEVNAME!
        echo   Cannot do full flash without partitions.
        pause
        goto :STARTUP
    )
) else if "%FMODE%"=="2" (
    set FLASH_TYPE=APP
) else (
    echo   [ERROR] Invalid mode!
    timeout /t 2 >nul
    goto :STARTUP
)

:: ── Detect flash size from device config ────────────────────
:: Default 4MB, override for known 16MB devices
set FLASH_SIZE=4MB
if "!DEVNAME!"=="BusLog_4G_v2" set FLASH_SIZE=16MB
if "!DEVNAME!"=="BusLog_4G_Lite" set FLASH_SIZE=16MB
if "!DEVNAME!"=="BusLog_IO_UNI_v1" set FLASH_SIZE=16MB

:: ── Setup logging ───────────────────────────────────────────
if not exist "logs" mkdir logs
set COUNT=0

:: ── Production Loop ─────────────────────────────────────────
:FLASH_LOOP
cls
echo.
echo   ====================================================
echo    SilTech Production Flash Tool
echo   ====================================================
echo.
echo   Device:     !DEVNAME!
echo   Flash Mode: !FLASH_TYPE!
echo   Flash Size: !FLASH_SIZE!
echo   COM Port:   %COMPORT%
echo   Flashed:    !COUNT! devices this session
echo.
echo   ====================================================
echo.
echo   [ENTER] = Flash next device
echo   [X]     = Change device / Exit
echo.
echo   ====================================================
echo.
set /p ACTION="   Ready? Press ENTER to flash (or X to exit): "

if /i "%ACTION%"=="X" goto :STARTUP
if /i "%ACTION%"=="x" goto :STARTUP

:: ── Re-check COM port (device might have been unplugged) ────
set COMPORT=
for /f "tokens=*" %%a in ('powershell -NoProfile -Command "Get-CimInstance Win32_PnPEntity | Where-Object { $_.Name -match 'CH340|CP210|FTDI|USB.Serial|Silicon Labs' -and $_.Name -match 'COM\d+' } | ForEach-Object { if ($_.Name -match '(COM\d+)') { $Matches[1] } } | Select-Object -First 1"') do set COMPORT=%%a

if "%COMPORT%"=="" (
    echo.
    echo   [ERROR] USB adapter disconnected! Plug it back in.
    echo.
    pause
    goto :FLASH_LOOP
)

:: ── Flash ───────────────────────────────────────────────────
echo.
echo   --------------------------------------------------------
echo    FLASHING... Do not unplug the device!
echo   --------------------------------------------------------
echo.

if "!FLASH_TYPE!"=="FULL" (
    esptool.exe --port %COMPORT% --baud 460800 --chip esp32 --after hard_reset ^
      write_flash --flash_mode dio --flash_size !FLASH_SIZE! ^
      0x1000  firmware\!DEVNAME!\bootloader.bin ^
      0x8000  firmware\!DEVNAME!\partitions.bin ^
      0x10000 firmware\!DEVNAME!\firmware.bin
) else (
    esptool.exe --port %COMPORT% --baud 460800 --chip esp32 --after hard_reset ^
      write_flash 0x10000 firmware\!DEVNAME!\firmware.bin
)

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo   ########################################
    echo   #      FLASH FAILED!                   #
    echo   #  Check cable and try again.           #
    echo   ########################################
    echo.
    echo   [%date% %time%] FAIL - !DEVNAME! on %COMPORT% >> logs\production_%date:~-4%%date:~4,2%%date:~7,2%.log
    pause
    goto :FLASH_LOOP
)

:: ── Flash Success ───────────────────────────────────────────
set /a COUNT+=1
echo.
echo   ========================================
echo    FLASH OK!  Device #!COUNT!
echo   ========================================
echo.
echo   [%date% %time%] OK #!COUNT! - !DEVNAME! on %COMPORT% >> logs\production_%date:~-4%%date:~4,2%%date:~7,2%.log

:: ── Auto-start Serial Monitor ───────────────────────────────
echo   Starting serial monitor... (press Q + Enter to stop)
echo   --------------------------------------------------------
echo.

powershell -ExecutionPolicy Bypass -File "%~dp0production_monitor.ps1" -ComPort %COMPORT%

:: ── After monitor exits, loop back ──────────────────────────
echo.
echo   Monitor closed. Ready for next device.
echo.
goto :FLASH_LOOP
