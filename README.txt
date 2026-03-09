# SilTech Debug Toolkit
## Field Service Tool — Zero-Install, Windows 10/11

Portable firmware flash + serial monitor for all SilTech IoT devices.
Copy the entire folder to any Windows PC — no installation needed.

## Quick Start

1. Plug in USB-TTL adapter (CH340/CP2102/FTDI)
2. Double-click `siltech_debug.bat`
3. Select device type → select action → done

## Contents

```
SilTech_Debug/
├── siltech_debug.bat    # Main menu — device selection + all tools
├── monitor.bat          # Quick-launch serial monitor
├── monitor.ps1          # PowerShell serial monitor (115200 baud)
├── esptool.exe          # esptool v5 standalone (no Python needed)
├── README.txt           # This file
└── firmware/
    ├── IO_Controller/   # GT01 10-channel cyclic controller
    ├── BusLog_4G_v2/    # BusLog 4G v2 (2 DI, 2 DO)
    ├── Tele_4G_AC/      # Tele 4G AC standard gateway
    ├── BusLog_4G_Lite/  # BusLog 4G Lite (no GPIO)
    └── BusLog_IO_UNI_v1/# BusLog IO UNI v1 (ESP32-S3, Ethernet)
```

## Menu Options

| Key | Action | Description |
|-----|--------|-------------|
| F | Flash App | Firmware only — keeps WiFi/config/SPIFFS |
| A | Flash Full | Bootloader + partitions + app — ERASES config |
| E | Erase | Wipe entire flash (for bricked devices) |
| M | Monitor | Serial monitor (115200 baud) |
| I | Info | Read chip ID, MAC, flash size |
| Q | Quit | Exit |

## Adding New Firmware

1. Create folder: `firmware\<DeviceName>\`
2. Copy `firmware.bin` (required)
3. Optionally add `bootloader.bin` + `partitions.bin` (for full flash)
4. Device will auto-appear in the menu

## COM Port Auto-Detection

Automatically finds USB-TTL adapters:
- CH340 / CH341
- CP2102 / CP2104
- FTDI
- Silicon Labs

If not detected, check Device Manager for the COM port number.

## Notes

- Flash baud: 460800 (fast, reliable)
- Monitor baud: 115200 (standard SilTech serial)
- BusLog_IO_UNI_v1 uses ESP32-S3 — esptool auto-detects chip
- Full flash uses `--flash-mode dio --flash-size 4MB` (ESP32 default)
- Monitor auto-launches after successful flash

## Troubleshooting

- **"No USB-TTL adapter found"** — Check USB cable / Device Manager
- **Flash fails** — Try erase first, then full flash
- **Device in boot loop** — Erase + full flash
- **Monitor garbled** — Check baud rate (should be 115200)
