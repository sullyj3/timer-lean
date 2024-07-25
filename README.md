# Sand
A systemd service and CLI program for setting countdown timers

### Building
You'll need a lean toolchain, which can be installed using [elan](https://github.com/leanprover/elan). 

Once that's done, run
```
lake build
```
### Dependencies
- libnotify
- pulseaudio (for timer notification sounds)

### Installation

This is currently only tested on Arch. If you use a different distro, you'll 
want to check and modify `install.sh` as appropriate. Let me know if this 
method is sufficient for your distro. PRs for better compatibility welcome. 

Distro specific packages TODO.

```bash
$ ./create_release.sh
$ cd release
$ sudo ./install.sh
```

### Usage
```
$ sand 30
sent message. Exiting

$ sand list
now: 32544974
10 | 32573115 (00:00:28:141 remaining)
```
A notification will be triggered when the timer elapses.
