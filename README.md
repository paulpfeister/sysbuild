# System Build Scripts and Playbooks

## ./Windows/

### WinClean - Windows bloat and telemetry mitigation
If the repository can't be cloned but a single file can be moved, the winclean.ps1 script can fetch *most* required assets remotely (provided that it can reach GitHub).

Alternatively, this snippet can be ran on the target machine (via an elevated shell) to run WinClean without any temporary files.
```ps
iex (iwr 'https://raw.githubusercontent.com/paulpfeister/sysbuild/master/Windows/winclean.ps1')
```