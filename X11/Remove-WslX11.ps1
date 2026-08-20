#Requires -RunAsAdministrator

$ListenPort = 6011

Write-Host "Removing WSL X11 portproxy entries..."

$proxyLines = netsh interface portproxy show v4tov4

foreach ($line in $proxyLines) {
    if ($line -match "^\s*(\S+)\s+$ListenPort\s+\S+\s+\d+\s*$") {
        $ListenAddress = $Matches[1]

        Write-Host "  Removing $ListenAddress`:$ListenPort"

        netsh interface portproxy delete v4tov4 `
            listenaddress=$ListenAddress `
            listenport=$ListenPort | Out-Null
    }
}

Get-NetFirewallRule -DisplayName "WSL X11 Bridge" `
    -ErrorAction SilentlyContinue |
    Remove-NetFirewallRule

Get-NetFirewallRule -DisplayName "Temporary WSL X11" `
    -ErrorAction SilentlyContinue |
    Remove-NetFirewallRule

Write-Host "WSL X11 Windows configuration removed."

