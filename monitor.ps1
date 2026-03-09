# SilTech Industries - Serial Monitor
# Auto-detects COM port, 115200 baud, logs to dated file
# Type commands and press Enter to send to device
# Press Ctrl+C to exit

$BAUD = 115200
$LOG_DIR = Join-Path $PSScriptRoot "logs"

Write-Host ""
Write-Host "  ================================================" -ForegroundColor Cyan
Write-Host "   SilTech Industries - Serial Monitor" -ForegroundColor Cyan
Write-Host "  ================================================" -ForegroundColor Cyan
Write-Host ""

# --- Auto-detect COM port ---
$ports = Get-CimInstance Win32_PnPEntity | Where-Object {
    $_.Name -match "CH340|CP210|FTDI|USB.Serial|USB-SERIAL|Silicon Labs" -and $_.Name -match "COM\d+"
}
if (-not $ports) {
    $ports = Get-CimInstance Win32_PnPEntity | Where-Object { $_.Name -match "COM\d+" }
}
if (-not $ports) {
    Write-Host "  [ERROR] No COM port found! Plug in USB-TTL adapter." -ForegroundColor Red
    Read-Host "  Press Enter to exit"
    exit 1
}

$comPorts = @()
foreach ($p in $ports) {
    if ($p.Name -match "(COM\d+)") {
        $comPorts += @{Name = $p.Name; Port = $Matches[1]}
    }
}

$selectedPort = $null
if ($comPorts.Count -eq 1) {
    $selectedPort = $comPorts[0].Port
    Write-Host "  Found: $($comPorts[0].Name)" -ForegroundColor Green
} else {
    Write-Host "  Multiple COM ports found:" -ForegroundColor Yellow
    for ($i = 0; $i -lt $comPorts.Count; $i++) {
        Write-Host "    [$($i+1)] $($comPorts[$i].Name)" -ForegroundColor White
    }
    $choice = Read-Host "  Select port (1-$($comPorts.Count))"
    $idx = [int]$choice - 1
    if ($idx -lt 0 -or $idx -ge $comPorts.Count) {
        Write-Host "  Invalid selection." -ForegroundColor Red
        exit 1
    }
    $selectedPort = $comPorts[$idx].Port
}

Write-Host "  Port: $selectedPort @ $BAUD baud" -ForegroundColor Green

# --- Log setup ---
if (-not (Test-Path $LOG_DIR)) { New-Item -ItemType Directory -Path $LOG_DIR | Out-Null }
$logFile = Join-Path $LOG_DIR ("debug_" + (Get-Date -Format "yyyy-MM-dd") + ".log")
Write-Host "  Log:  $logFile" -ForegroundColor Green
Write-Host ""
Write-Host "  Type commands + Enter to send. Press Q + Enter to quit." -ForegroundColor DarkGray
Write-Host "  ------------------------------------------------" -ForegroundColor DarkGray
Write-Host ""

# --- Open serial port ---
$port = New-Object System.IO.Ports.SerialPort $selectedPort, $BAUD, "None", 8, "One"
$port.DtrEnable = $false
$port.RtsEnable = $false
$port.ReadTimeout = -1
$port.Encoding = [System.Text.Encoding]::UTF8

try {
    $port.Open()
} catch {
    Write-Host "  [ERROR] Cannot open $selectedPort - is it in use?" -ForegroundColor Red
    Write-Host "  $($_.Exception.Message)" -ForegroundColor DarkRed
    Read-Host "  Press Enter to exit"
    exit 1
}

# --- Register cleanup on exit/Ctrl+C ---
$cleanup = {
    if ($port -and $port.IsOpen) {
        $port.Close()
        $port.Dispose()
    }
}
Register-EngineEvent PowerShell.Exiting -Action $cleanup | Out-Null
[Console]::TreatControlCAsInput = $true

Add-Content -Path $logFile -Value "`n=== Session started $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') on $selectedPort ==="

$inputBuffer = ""
$running = $true

while ($running -and $port.IsOpen) {
    # --- Read serial data (non-blocking) ---
    if ($port.BytesToRead -gt 0) {
        $data = $port.ReadExisting()
        if ($data) {
            $lines = $data -split "`n"
            foreach ($rawLine in $lines) {
                $line = $rawLine.TrimEnd("`r")
                if ($line.Length -eq 0) { continue }
                $ts = Get-Date -Format "HH:mm:ss.fff"
                $display = "[$ts] $line"
                Write-Host $display
                Add-Content -Path $logFile -Value $display
            }
        }
    }

    # --- Check keyboard input (non-blocking) ---
    while ([Console]::KeyAvailable) {
        $key = [Console]::ReadKey($true)

        # Ctrl+C - clean exit
        if ($key.Modifiers -band [ConsoleModifiers]::Control -and $key.Key -eq "C") {
            $running = $false
            break
        }

        if ($key.Key -eq "Enter") {
            Write-Host ""
            if ($inputBuffer -eq "q" -or $inputBuffer -eq "Q" -or $inputBuffer -eq "quit" -or $inputBuffer -eq "exit") {
                $running = $false
                break
            }
            if ($inputBuffer.Length -gt 0) {
                $port.WriteLine($inputBuffer)
                $ts = Get-Date -Format "HH:mm:ss.fff"
                $sent = "[$ts] >> $inputBuffer"
                Write-Host $sent -ForegroundColor Yellow
                Add-Content -Path $logFile -Value $sent
                $inputBuffer = ""
            }
        }
        elseif ($key.Key -eq "Backspace") {
            if ($inputBuffer.Length -gt 0) {
                $inputBuffer = $inputBuffer.Substring(0, $inputBuffer.Length - 1)
                Write-Host "`b `b" -NoNewline
            }
        }
        else {
            $inputBuffer += $key.KeyChar
            Write-Host $key.KeyChar -NoNewline -ForegroundColor Yellow
        }
    }

    Start-Sleep -Milliseconds 50
}

# --- Guaranteed cleanup ---
[Console]::TreatControlCAsInput = $false
if ($port.IsOpen) {
    $port.Close()
}
$port.Dispose()
Add-Content -Path $logFile -Value "=== Session ended $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ==="
Write-Host ""
Write-Host "  Port closed. Log saved to $logFile" -ForegroundColor Cyan
Write-Host "  Press Enter to exit..." -ForegroundColor DarkGray
Read-Host
