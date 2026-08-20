Goal
----
Prevent Windows going into sleep or hibernating as long as there is a running
WSL, and prevent the WSL from exiting on its own. This is achieved by
recognising when a WSL is spawned and spawning another WSL session in parallel
which won't die on its own.


Script
------
Setting up the script in done with PowerShell.
In a command shell session, first create a directory for this app:
```powershell
mkdir "%LOCALAPPDATA%\WslKeepAwake"
```
and move the script there:
```cmd
move Watch-Wsl.ps1 "%LOCALAPPDATA%\WslKeepAwake\Watch-Wsl.ps1"
```


Test
----
Let us first test if the script works as it should. First, make sure no
active WSL are running (in a command shell):
```cmd
wsl --shutdown
```
Then, start the script manually (in a PowerShell):
```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
    -File "$env:LOCALAPPDATA\WslKeepAwake\Watch-Wsl.ps1"
```
Initially, you'll just see:
```
WSL keep-awake watcher started.
```
In another shell, start WSL:
```cmd
wsl
```
The watcher should then report something along the lines of:
```
WSL active: Ubuntu
Windows sleep inhibited.
```
Keep the WSL active and the script running. From the Windows command shell,
test if sleep is inhibited:
```cmd
powercfg /requests
```
It should show something like
```
SYSTEM:

[PROCESS] \Device\HarddiskVolume3\Windows\System32\WindowsPowerShell\v1.0\powershell.exe
```
and
```cmd
wsl --list --running
```
Should show Ubuntu.
Now exit the WSL shell. WSL should remain listed as running, because the hidden
`wsl.exe ... sleep infinity` process is holding it open.

Finally, shutdown the WSL:
```cmd
wsl --shutdown
```
Wait a few seconds, then run:
```cmd
powercfg /requests
```
You should now see:
```
SYSTEM:

None.
```
The watcher should have printed:
```
Windows sleep inhibition released.
```
and
```cmd
wsl --list --running
```
should show none.


Automatic behaviour on boot
---------------------------
Once the manual test works, we can register the script with Windows Task
Scheduler so we don't have to start it by hand.
In PowerShell:
```powershell
$script = "$env:LOCALAPPDATA\WslKeepAwake\Watch-Wsl.ps1"

$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$script`""

$trigger = New-ScheduledTaskTrigger -AtStartup

$sid = ([System.Security.Principal.WindowsIdentity]::GetCurrent()).User.Value

$principal = New-ScheduledTaskPrincipal `
    -UserId $sid `
    -LogonType S4U `
    -RunLevel Highest

$settings = New-ScheduledTaskSettingsSet `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit ([TimeSpan]::Zero)

Register-ScheduledTask `
    -TaskName "WSL Keep Awake" `
    -Action $action `
    -Trigger $trigger `
    -Principal $principal `
    -Settings $settings `
    -Description "Prevent Windows sleep while a WSL distribution is running."
```
Because we're already logged in, registering an AtLogOn task won't necessarily start this instance immediately. So start it once now:
```powershell
Start-ScheduledTask -TaskName "WSL Keep Awake"
```
You can check:
```
Get-ScheduledTask -TaskName "WSL Keep Awake"
```
and:
```
Get-ScheduledTaskInfo -TaskName "WSL Keep Awake"
```

Done, it all works on its own now!

Don't forget to shutdown the WSL to reallow hibernation again:
```cmd
wsl --shutdown
```
