Goal
---
Set up a route for X11 to work on WSL without the need for mirroring

Local X server prerequisite
---------------------------
This setup reserves TCP ports 6010 and 6011 for the X11 bridge.

The client must provide an X11 server reachable at localhost:6000.
 - XQuartz: normally available directly.
 - Xorg: enable local TCP listening if desired.
 - XWayland: use a localhost-only TCP→X11 Unix-socket bride; (e.g. somethinglike
```bash
   socat TCP-LISTEN:6000,bind=127.0.0.1,reuseaddr,fork \
   UNIX-CONNECT:/tmp/.X11-unix/X0
```
Test:
```bash
    DISPLAY=localhost:0 xdpyinfo
```
If this fails, the local X server is not listening on TCP port 6000 and the
RemoteForward configuration cannot be used as-is.


Troubleshooting
---------------
x11diag: Windows bridge FAIL
    Run Update-WslX11.ps1 as Administrator on Windows.

x11diag: X11 handshake TIMEOUT
    Reconnect the SSH session from the client machine.
    The RemoteForward on port 6010 is probably missing.

"Invalid MIT-MAGIC-COOKIE-1 key"
or "Authorization required"
    Run x11cookie on the client machine.
Do NOT use `xhost +` as part of the normal setup.
The helper uses MIT-MAGIC-COOKIE authentication.

DISPLAY is :0 in WSL
    This is normal WSLg behaviour.
    Run x11client to switch the current shell to the remote client display.


Install
------

On Windows:
 - Copy Update-WslX11.ps1 (to add firewall rules) and Remove-WslX11.ps1 (to undo firewall
   rules if ever needed) to user home (or write the contents manually using "edit <filename>")
 - To run these scripts, one needs elevated rights.
   If you are in a `cmd.exe` with elevated rights, you can just do:
```cmd
      powershell.exe -ExecutionPolicy Bypass -File "%USERPROFILE%\Update-WslX11.ps1"
```
   If not, you will need to run this locally on the machine (because it will give a prompt):
```cmd
      powershell.exe -Command "Start-Process powershell.exe -Verb RunAs -ArgumentList '-ExecutionPolicy Bypass -File \"%USERPROFILE%\Update-WslX11.ps1\"'"
```

On WSL:
 - `sudo apt install x11-apps xauth x11-utils` (if Ubuntu/Debian)
 - Add contents of shellrc_wsl into ~/.bashrc (or relevant shell init)
 - This will automatically run `x11diag` at each login and tell you what to do

On client machine:
 - Add contents of shellrc_client into ~/.bashrc (or relevant shell init)
 - Add contents of sshconfig_client into ~/.ssh/config
 - `source ~/.bashrc` and run `x11cookie windows-wsl` (or replace windows-wsl with another
   SSH Host alias if desired)

Make a new SSH connection (after updating the config above), login to WSL, start the X11
route with `x11client`, and test with `xclock` (or `xeyes`, or anything else).

You can also test with matplotlib:
```python
  import matplotlib.pyplot as plt
  plt.plot([1, 2, 3])
  plt.show()
```
