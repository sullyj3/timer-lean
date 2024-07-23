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
- mpv (optional, for notification sounds)

### Installation
(TODO)

### Usage
```
$ sand 30
sent message. Exiting

$ sand list
now: 32544974
10 | 32573115 (00:00:28:141 remaining)
```
A notification will be triggered when the timer elapses.
