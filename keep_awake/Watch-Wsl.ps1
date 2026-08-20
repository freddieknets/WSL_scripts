Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class PowerUtil {
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern uint SetThreadExecutionState(uint esFlags);
}
"@

[uint32]$ES_CONTINUOUS      = [uint32]"0x80000000"
[uint32]$ES_SYSTEM_REQUIRED = [uint32]"0x00000001"

$keepers = @{}
$sleepInhibited = $false

Write-Output "WSL keep-awake watcher started."

try {
    while ($true) {

        $running = @(
            wsl.exe --list --running --quiet 2>$null |
                ForEach-Object { ($_ -replace "`0", "").Trim() } |
                Where-Object { $_.Length -gt 0 }
        )

        # Forget keeper processes that have terminated.
        foreach ($distro in @($keepers.Keys)) {
            if ($keepers[$distro].HasExited) {
                $keepers.Remove($distro)
            }
        }

        # Establish a persistent Windows-side connection to every
        # distro that is already running.
        foreach ($distro in $running) {
            if (-not $keepers.ContainsKey($distro)) {
                Write-Output "WSL active: $distro"

                $process = Start-Process `
                    -FilePath "wsl.exe" `
                    -ArgumentList "-d", $distro, "--exec", "sleep", "infinity" `
                    -WindowStyle Hidden `
                    -PassThru

                $keepers[$distro] = $process
            }
        }

        $wslActive = ($running.Count -gt 0)

        if ($wslActive -and -not $sleepInhibited) {
            [void][PowerUtil]::SetThreadExecutionState(
                $ES_CONTINUOUS -bor $ES_SYSTEM_REQUIRED
            )
            $sleepInhibited = $true
            Write-Output "Windows sleep inhibited."
        }
        elseif (-not $wslActive -and $sleepInhibited) {
            [void][PowerUtil]::SetThreadExecutionState($ES_CONTINUOUS)
            $sleepInhibited = $false
            Write-Output "Windows sleep inhibition released."
        }

        Start-Sleep -Seconds 5
    }
}
finally {
    [void][PowerUtil]::SetThreadExecutionState($ES_CONTINUOUS)
}