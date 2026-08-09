#Requires -RunAsAdministrator

$ListenPort = 6011
$TargetPort = 6010

$FirewallRuleName = "WSL X11 Bridge"
$OldFirewallRuleName = "Temporary WSL X11"

Write-Host "Discovering current WSL networking..."

# ------------------------------------------------------------
# Find Windows host IP as seen from WSL
# ------------------------------------------------------------

$route = (& wsl.exe ip route show default | Out-String).Trim()

if ($route -notmatch 'default\s+via\s+(\d+\.\d+\.\d+\.\d+)') {
    throw "Could not determine the Windows host IP from the WSL default route."
}

$WindowsWslIP = $Matches[1]

# ------------------------------------------------------------
# Find WSL's own current IPv4 address
# ------------------------------------------------------------

$routeToWindows = (
    & wsl.exe sh -lc "ip -4 route get $WindowsWslIP"
    | Out-String
).Trim()

if ($routeToWindows -notmatch '\bsrc\s+(\d+\.\d+\.\d+\.\d+)') {
    throw "Could not determine the WSL IPv4 address."
}

$WslIP = $Matches[1]

Write-Host "Windows as seen from WSL : $WindowsWslIP"
Write-Host "WSL address              : $WslIP"
Write-Host

# ------------------------------------------------------------
# Remove any OLD portproxy belonging to our port 6011
# Do NOT touch unrelated portproxy entries.
# ------------------------------------------------------------

Write-Host "Removing stale X11 portproxy entries..."

$proxyLines = netsh interface portproxy show v4tov4

foreach ($line in $proxyLines) {
    if ($line -match '^\s*(\S+)\s+6011\s+\S+\s+\d+\s*$') {
        $OldListenAddress = $Matches[1]

        Write-Host "  Removing $OldListenAddress`:6011"

        netsh interface portproxy delete v4tov4 `
            listenaddress=$OldListenAddress `
            listenport=$ListenPort | Out-Null
    }
}

# ------------------------------------------------------------
# Add current proxy
# ------------------------------------------------------------

Write-Host "Creating portproxy:"
Write-Host "  $WindowsWslIP`:$ListenPort -> 127.0.0.1`:$TargetPort"

netsh interface portproxy add v4tov4 `
    listenaddress=$WindowsWslIP `
    listenport=$ListenPort `
    connectaddress=127.0.0.1 `
    connectport=$TargetPort

# ------------------------------------------------------------
# Replace our firewall rule
# ------------------------------------------------------------

Write-Host "Updating firewall rule..."

Get-NetFirewallRule -DisplayName $FirewallRuleName `
    -ErrorAction SilentlyContinue |
    Remove-NetFirewallRule

# Clean up the original rule we made manually, if still present.
Get-NetFirewallRule -DisplayName $OldFirewallRuleName `
    -ErrorAction SilentlyContinue |
    Remove-NetFirewallRule

New-NetFirewallRule `
    -DisplayName $FirewallRuleName `
    -Direction Inbound `
    -Action Allow `
    -Protocol TCP `
    -LocalAddress $WindowsWslIP `
    -LocalPort $ListenPort `
    -RemoteAddress $WslIP |
    Out-Null

Write-Host
Write-Host "Current portproxy:"
netsh interface portproxy show v4tov4

Write-Host
Write-Host "Firewall:"
Get-NetFirewallRule -DisplayName $FirewallRuleName |
    Get-NetFirewallAddressFilter

Write-Host
Write-Host "Done."
Write-Host
Write-Host "Now test from WSL:"
Write-Host "  x11diag"
