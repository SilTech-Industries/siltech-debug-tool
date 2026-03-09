SilTech Industries - Debug & Production Toolkit
================================================

Two tools in one package:

1. siltech_debug.bat    - Field debugging (technicians)
2. production_flash.bat - Factory floor flashing (workers)


PRODUCTION FLASH TOOL (production_flash.bat)
--------------------------------------------
For factory workers flashing new devices off the assembly line.

How to use:
  1. Double-click production_flash.bat
  2. Select device type (e.g. BusLog_4G_v2)
  3. Select flash mode (Full Flash for new devices)
  4. Connect device via USB cable
  5. Press ENTER to flash
  6. Device flashes + auto-resets + monitor starts
  7. Check serial output for errors
  8. Press Q + Enter to stop monitor
  9. Disconnect device, connect next one
  10. Press ENTER to flash next device
  11. Repeat!

Logs saved to: logs\production_YYYY-MM-DD.log


DEBUG TOOL (siltech_debug.bat)
------------------------------
For field technicians debugging deployed devices.

Features:
  F - Flash App Only (keeps config)
  A - Full Flash (bootloader + partitions + app)
  E - Erase Flash (nuclear option)
  M - Serial Monitor
  I - Device Info (chip ID, MAC, flash)

Logs saved to: logs\debug_YYYY-MM-DD.log


REQUIREMENTS
------------
- Windows 10/11
- CH340 or CP2102 USB-to-serial adapter
- USB driver installed (CH340: wch-ic.com/downloads)
- No other software needed (esptool.exe included)


SUPPORTED DEVICES
-----------------
- Tele_4G_AC
- BusLog_4G_v2
- BusLog_4G_Lite
- BusLog4G_Bat_A / B / C
- BusLog4G_Bat_IO
- BusLog_IO_UNI_v1
- IO_Controller


TROUBLESHOOTING
---------------
"No USB adapter detected"
  → Install CH340 driver from wch-ic.com/downloads
  → Try a different USB port
  → Check Device Manager for COM port

"Flash failed"
  → Hold BOOT button on device while starting flash
  → Check TX/RX/GND connections
  → Try lower baud: edit .bat file, change 460800 to 115200

"Monitor shows garbage"
  → Baud rate mismatch (should be 115200)
  → Check TX/RX not swapped
